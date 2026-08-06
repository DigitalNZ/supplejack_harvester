# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelineJob do
  let(:destination)        { create(:destination) }

  describe 'associations' do
    it { is_expected.to have_many(:harvest_reports) }
  end

  describe '#validations' do
    subject                  { create(:pipeline_job, pipeline:, destination:) }

    let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
    let(:harvest_definition) { create(:harvest_definition, pipeline:) }

    it 'requires pages if the page_type is set_number' do
      job = build(:pipeline_job, pipeline:, destination:, page_type: 'set_number')

      expect(job).not_to be_valid
      expect(job.errors['pages']).to include "can't be blank"
    end

    it 'does not requires pages if the page_type is all_available_pages' do
      job = build(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages')

      expect(job).to be_valid
    end
  end

  describe '#advance_to_next_block' do
    let(:pipeline)     { create(:pipeline) }
    let!(:pre_zero)    { create(:harvest_definition, :preprocess, pipeline:, position: 0) }
    let!(:pre_one)     { create(:harvest_definition, :preprocess, pipeline:, position: 1) }
    let(:pipeline_job) do
      create(:pipeline_job, pipeline:, destination:,
                            harvest_definitions_to_run: pipeline.harvest_definitions.pluck(:id))
    end

    it 'enqueues a HarvestJob for the next block by position' do
      allow(HarvestWorker).to receive(:perform_async_with_priority)

      expect do
        pipeline_job.advance_to_next_block(pre_zero)
      end.to change { pipeline_job.harvest_jobs.where(harvest_definition: pre_one).count }.by(1)

      expect(HarvestWorker).to have_received(:perform_async_with_priority)
    end

    it 'is idempotent when the next block already has a job' do
      allow(HarvestWorker).to receive(:perform_async_with_priority)
      create(:harvest_job, pipeline_job:, harvest_definition: pre_one)

      expect do
        pipeline_job.advance_to_next_block(pre_zero)
      end.not_to(change { pipeline_job.harvest_jobs.where(harvest_definition: pre_one).count })
    end

    it 'neither duplicates the job nor enqueues a worker when completion signals race' do
      allow(HarvestWorker).to receive(:perform_async_with_priority)

      # The winning racer's row is already committed; this losing call must
      # hit the unique index and back off without enqueueing anything.
      create(:harvest_job, pipeline_job:, harvest_definition: pre_one)

      expect do
        pipeline_job.advance_to_next_block(pre_zero)
      end.not_to(change { pipeline_job.harvest_jobs.where(harvest_definition: pre_one).count })

      expect(HarvestWorker).not_to have_received(:perform_async_with_priority)
    end

    it 'falls through to enrichments when there is no next block' do
      expect(pipeline_job).to receive(:enqueue_enrichment_jobs).with(pre_one.name)

      pipeline_job.advance_to_next_block(pre_one)
    end

    it 'no-ops when the pipeline job is cancelled' do
      pipeline_job.cancelled!

      expect(HarvestWorker).not_to receive(:perform_async_with_priority)

      expect do
        pipeline_job.advance_to_next_block(pre_zero)
      end.not_to(change { pipeline_job.harvest_jobs.count })
    end
  end

  describe '#maybe_still_writing?' do
    let(:pipeline) { create(:pipeline) }

    it 'is true for an unfinished run created within the last day' do
      job = create(:pipeline_job, pipeline:, destination:, status: 'running', created_at: 2.hours.ago)

      expect(job.maybe_still_writing?).to be true
    end

    it 'is false for an unfinished run older than a day' do
      job = create(:pipeline_job, pipeline:, destination:, status: 'running', created_at: 25.hours.ago)

      expect(job.maybe_still_writing?).to be false
    end

    it 'is false for a finished run, however recent' do
      job = create(:pipeline_job, pipeline:, destination:, status: 'completed', created_at: 2.hours.ago)

      expect(job.maybe_still_writing?).to be false
    end
  end
end
