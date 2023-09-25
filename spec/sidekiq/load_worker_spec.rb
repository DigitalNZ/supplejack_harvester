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

  describe '#perform' do
    let(:harvest_job) { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }
    let!(:harvest_report) do
      create(:harvest_report, harvest_job:, pipeline_job:, extraction_status: 'completed',
                              transformation_status: 'completed', delete_status: 'completed', load_workers_queued: 1)
    end

    let!(:field) do
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                     transformation_definition: enrichment_definition.transformation_definition)
    end

    context 'when the harvest has completed' do
      it 'queues scoped enrichments that are ready to be run' do
        expect(HarvestWorker).to receive(:perform_async)

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
  end
end
