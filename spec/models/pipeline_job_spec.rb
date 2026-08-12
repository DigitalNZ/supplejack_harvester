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

  describe '#retained?' do
    it 'is false by default' do
      expect(create(:pipeline_job).retained?).to be false
    end

    it 'is true once retained_at is stamped' do
      job = create(:pipeline_job, retained_at: Time.zone.now)

      expect(job.retained?).to be true
    end
  end

  describe '.preprocess_sweep_candidates' do
    let(:pipeline) { create(:pipeline) }
    # The real PreProcessRetentionPolicy gains keep_latest in a later commit;
    # a Struct keeps this unit spec independent of the config file's shape.
    let(:policy) { Struct.new(:keep_latest).new(2) }

    def run(pipeline, created_at, status: 'completed')
      create(:pipeline_job, pipeline:, destination:, status:, created_at:)
    end

    it 'returns the runs beyond the newest keep_latest for a pipeline' do
      oldest = run(pipeline, 5.days.ago)
      run(pipeline, 4.days.ago)
      run(pipeline, 3.days.ago)

      candidates = described_class.preprocess_sweep_candidates(policy, described_class.pluck(:id))

      expect(candidates).to eq [oldest]
    end

    it 'ranks each pipeline separately' do
      other_pipeline = create(:pipeline)
      old_a = run(pipeline, 5.days.ago)
      run(pipeline, 4.days.ago)
      run(pipeline, 3.days.ago)
      old_b = run(other_pipeline, 6.days.ago)
      run(other_pipeline, 4.days.ago)
      run(other_pipeline, 3.days.ago)

      candidates = described_class.preprocess_sweep_candidates(policy, described_class.pluck(:id))

      expect(candidates).to contain_exactly(old_a, old_b)
    end

    it 'only ranks runs whose output is still on disk' do
      oldest = run(pipeline, 5.days.ago)
      middle = run(pipeline, 4.days.ago)
      run(pipeline, 3.days.ago)

      candidates = described_class.preprocess_sweep_candidates(policy, [oldest.id, middle.id])

      expect(candidates).to be_empty
    end

    it 'skips an out-ranked run that might still be writing' do
      run(pipeline, 2.hours.ago, status: 'running')
      run(pipeline, 1.hour.ago)
      run(pipeline, 30.minutes.ago)

      candidates = described_class.preprocess_sweep_candidates(policy, described_class.pluck(:id))

      expect(candidates).to be_empty
    end

    it 'includes an out-ranked unfinished run once it is older than a day' do
      # A crashed run stays "running" forever, and a preprocess-only pipeline
      # never completes; the writing window is what lets keep-N reclaim them.
      abandoned = run(pipeline, 3.days.ago, status: 'running')
      run(pipeline, 2.days.ago)
      run(pipeline, 1.day.ago)

      candidates = described_class.preprocess_sweep_candidates(policy, described_class.pluck(:id))

      expect(candidates).to eq [abandoned]
    end

    it 'breaks created_at ties by id, treating the higher id as newer' do
      born = 3.days.ago
      first = run(pipeline, born)
      run(pipeline, born)
      run(pipeline, born)

      candidates = described_class.preprocess_sweep_candidates(policy, described_class.pluck(:id))

      expect(candidates).to eq [first]
    end

    it 'only returns runs for the given pipeline when scoped' do
      other_pipeline = create(:pipeline)
      old_ours = run(pipeline, 5.days.ago)
      run(pipeline, 4.days.ago)
      run(pipeline, 3.days.ago)
      run(other_pipeline, 6.days.ago)
      run(other_pipeline, 4.days.ago)
      run(other_pipeline, 3.days.ago)

      candidates = described_class.preprocess_sweep_candidates(policy, described_class.pluck(:id),
                                                               pipeline_id: pipeline.id)

      expect(candidates).to eq [old_ours]
    end
  end
end
