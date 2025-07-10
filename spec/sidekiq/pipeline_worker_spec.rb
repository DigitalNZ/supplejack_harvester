# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelineWorker, type: :job do
  let(:destination)            { create(:destination) }
  let(:pipeline)               { create(:pipeline, :figshare) }
  let(:harvest_definition)     { pipeline.harvest }
  let(:enrichment_definitions) { create_list(:harvest_definition, 2, kind: 'enrichment', pipeline:) }
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
  end
end
