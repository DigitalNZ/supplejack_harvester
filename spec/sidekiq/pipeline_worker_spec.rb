# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelineWorker, type: :job do
  let(:destination)            { create(:destination) }
  let(:pipeline)               { create(:pipeline, :figshare) }
  let(:harvest_definition)     { runnable(pipeline.harvest) }
  let(:enrichment_definitions) { create_list(:harvest_definition, 2, kind: 'enrichment', pipeline:).map { runnable(it) } }

  # PipelineWorker refuses to start a block that cannot run, and a transformation with no
  # fields is one of the reasons a block cannot - see BlockConfiguration. The factory leaves
  # one empty, so a block this spec means to see started needs a field of its own.
  def runnable(definition)
    create(:field, transformation_definition: definition.transformation_definition)
    definition
  end
  let(:harvest_and_enrichment_pipeline_job) do
    create(:pipeline_job, pipeline:, destination:,
                          harvest_definitions_to_run: [harvest_definition.id, enrichment_definitions.map(&:id)].flatten,
                          job_priority: 'high_priority')
  end
  let(:enrichment_only_pipeline_job) do
    create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: enrichment_definitions.map(&:id), job_priority: 'high_priority')
  end

  describe '#perform' do
    context 'when the harvest definitions to run includes a harvest' do
      it 'creates a HarvestJob for the harvest only' do
        expect do
          described_class.new.perform(harvest_and_enrichment_pipeline_job.id)
        end.to change(HarvestJob, :count).by(1)
      end

      it 'enqueues a HarvestWorker' do
        expect(HarvestWorker).to receive(:perform_async_with_priority).with('high_priority', anything)

        described_class.new.perform(harvest_and_enrichment_pipeline_job.id)
      end
    end

    context 'when the harvest definitions to run does not include a harvest' do
      it 'creates a HarvestJob for each enrichment' do
        expect do
          described_class.new.perform(enrichment_only_pipeline_job.id)
        end.to change(HarvestJob, :count).by(2)
      end

      it 'schedules a HarvestWorker for each enrichment' do
        expect(HarvestWorker).to receive(:perform_async_with_priority).with('high_priority', anything).twice

        described_class.new.perform(enrichment_only_pipeline_job.id)
      end
    end

    context 'when the pipeline job has a job_priority' do
      it 'enqueues the job into the specified queue' do
        expect(HarvestWorker).to receive(:perform_async_with_priority).with('high_priority', anything)

        described_class.new.perform(harvest_and_enrichment_pipeline_job.id)
      end
    end

    # The Run modal will not tick a block that cannot run, but a schedule saved before the
    # block broke, an API post naming every block, and a definition deleted while the run
    # waited in the queue all get here anyway.
    context 'when a block the run asked for cannot run' do
      let(:broken_run) do
        create(:pipeline_job, pipeline:, destination:, job_priority: 'high_priority',
                              harvest_definitions_to_run: [harvest_definition.id])
      end

      before { harvest_definition.update!(load_definition: nil) }

      it 'starts nothing' do
        expect { described_class.new.perform(broken_run.id) }.not_to change(HarvestJob, :count)
      end

      it 'queues no worker' do
        expect(HarvestWorker).not_to receive(:perform_async_with_priority)

        described_class.new.perform(broken_run.id)
      end

      # Left running, the run would sit in the jobs table looking like it was still going.
      it 'ends the run as errored' do
        described_class.new.perform(broken_run.id)

        expect(broken_run.reload).to have_attributes(status: 'errored', end_time: be_present)
      end
    end

    it 'starts a run whose own blocks are fine while another block of the pipeline is broken' do
      create(:harvest_definition, pipeline:, kind: 'enrichment', source_id: 'broken', load_definition: nil)
      run = create(:pipeline_job, pipeline:, destination:, job_priority: 'high_priority',
                                  harvest_definitions_to_run: [harvest_definition.id])

      expect { described_class.new.perform(run.id) }.to change(HarvestJob, :count).by(1)
    end

    context 'when the pipeline has a preprocess chain' do
      let!(:pre_zero) { runnable(create(:harvest_definition, :preprocess, pipeline:, position: 0)) }
      let!(:pre_one)  { runnable(create(:harvest_definition, :preprocess, pipeline:, position: 1)) }
      let(:chain_pipeline_job) do
        create(:pipeline_job, pipeline:, destination:, job_priority: 'high_priority',
                              harvest_definitions_to_run: [pre_zero.id, pre_one.id, harvest_definition.id])
      end

      before { harvest_definition.update!(position: 2) }

      it 'starts only the first block in the chain' do
        expect do
          described_class.new.perform(chain_pipeline_job.id)
        end.to change(HarvestJob, :count).by(1)

        expect(chain_pipeline_job.harvest_jobs.first.harvest_definition).to eq(pre_zero)
      end

      it 'falls back to the legacy behaviour for an enrichment-only run' do
        job = create(:pipeline_job, pipeline:, destination:, job_priority: 'high_priority',
                                    harvest_definitions_to_run: enrichment_definitions.map(&:id))

        expect do
          described_class.new.perform(job.id)
        end.to change(HarvestJob, :count).by(2)
      end
    end
  end
end
