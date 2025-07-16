# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadWorker, type: :job do
  let!(:pipeline)              { create(:pipeline, :figshare) }
  let!(:harvest_definition)    { pipeline.harvest }
  let!(:enrichment_definition) { create(:harvest_definition, kind: 'enrichment', pipeline:) }
  let(:destination)            { create(:destination) }
  let(:pipeline_job)           do
    create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [enrichment_definition.id], key: 'test')
  end

  def stub_notice_to_api
    notifier = instance_double('Api::Utils::NotifyHarvesting')
    expect(notifier).to receive(:call)
    expect(Api::Utils::NotifyHarvesting).to receive(:new) { notifier }
  end

  describe '#perform' do
    let(:harvest_job) { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }
    let!(:harvest_report) do
      create(
        :harvest_report,
        harvest_job:,
        pipeline_job:,
        extraction_status: 'completed',
        transformation_status: 'completed',
        delete_status: 'completed',
        load_workers_queued: 1
      )
    end

    let!(:field) do
      create(
        :field,
        name: 'title',
        block: "JsonPath.new('title').on(record).first",
        transformation_definition: enrichment_definition.transformation_definition
      )
    end

    context 'when the harvest has completed' do
      it 'queues scoped enrichments that are ready to be run' do
        expect(HarvestWorker).to receive(:perform_async)
        stub_notice_to_api

        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.to change(HarvestJob, :count).by(1)

        expect(HarvestJob.last.target_job_id).to eq harvest_job.name
      end

      it 'does not queue enrichments if there is already an existing enrichment with the same key' do
        create(
          :harvest_job,
          :completed,
          harvest_definition: enrichment_definition,
          pipeline_job:,
          key: "test__enrichment-#{enrichment_definition.id}"
        )
        stub_notice_to_api

        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.not_to change(HarvestJob, :count)
      end
    end

    context 'when the harvest is not completed' do
      let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:, key: 'test') }
      let!(:harvest_report) do
        create(:harvest_report, harvest_job:, pipeline_job:, extraction_status: 'running', transformation_status: 'running',
                                delete_status: 'running', load_workers_queued: 1)
      end

      it 'does not queue enrichments' do
        expect(HarvestWorker).not_to receive(:perform_async)

        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.not_to change(HarvestJob, :count)
      end
    end

    context 'when the harvest job is cancelled' do
      let(:cancelled_harvest_job) { create(:harvest_job, :cancelled, harvest_definition:, pipeline_job:) }
      let!(:cancelled_harvest_report) do
        create(:harvest_report, harvest_job: cancelled_harvest_job, pipeline_job:)
      end
      
      it 'does not process any batches when harvest job is cancelled' do
        expect(Load::Execution).not_to receive(:new)
        
        described_class.new.perform(cancelled_harvest_job.id, '[{"id": "1"}]')
      end
    end
    
    context 'when the pipeline job is cancelled' do
      let(:cancelled_pipeline_job) { create(:pipeline_job, :cancelled, pipeline:, destination:) }
      let(:harvest_job_with_cancelled_pipeline) { create(:harvest_job, harvest_definition:, pipeline_job: cancelled_pipeline_job) }
      let!(:cancelled_pipeline_harvest_report) do
        create(:harvest_report, harvest_job: harvest_job_with_cancelled_pipeline, pipeline_job: cancelled_pipeline_job)
      end
      
      it 'does not process any batches when pipeline job is cancelled' do
        expect(Load::Execution).not_to receive(:new)
        
        described_class.new.perform(harvest_job_with_cancelled_pipeline.id, '[{"id": "1"}]')
      end
    end

    context 'when the Load Execution raises an exception' do
      before do
        allow_any_instance_of(Load::Execution).to receive(:call).and_raise(StandardError)
      end

      it 'retries the Load Execution' do
        stub_notice_to_api
        expect(Load::Execution).to receive(:new).exactly(2).times
        described_class.new.perform(harvest_job.id, "[{\"transformed_record\":{\"internal_identifier\":\"test\"}}]")
      end

      it 'still increments the number of workers completed' do
        stub_notice_to_api
        expect(harvest_report.load_workers_queued).to eq 1
        expect(harvest_report.load_workers_completed).to eq 0

        described_class.new.perform(harvest_job.id, "[{\"transformed_record\":{\"internal_identifier\":\"test\"}}]")
        harvest_report.reload

        expect(harvest_report.load_workers_completed).to eq 1
      end
    end

    context "when the Api::Utils::NotifyHarvesting raises an exception" do
      before do
        allow_any_instance_of(Api::Utils::NotifyHarvesting).to receive(:call).and_raise(StandardError)
      end

      it "retries the Api::Utils::NotifyHarvesting" do
        expect(Api::Utils::NotifyHarvesting).to receive(:new).exactly(2).times
        described_class.new.perform(harvest_job.id, "[]")
      end

      it "still enqueues enrichment jobs" do
        expect do
          described_class.new.perform(harvest_job.id, '[]')
        end.to change(HarvestJob, :count).by(1)

        expect(HarvestJob.last.target_job_id).to eq harvest_job.name
      end
    end
  end
end
