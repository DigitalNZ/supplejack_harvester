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

  describe 'run configuration' do
    let(:pipeline)     { create(:pipeline) }
    let!(:pre_zero)    { create(:harvest_definition, :preprocess, pipeline:, position: 0) }
    let!(:pre_one)     { create(:harvest_definition, :preprocess, pipeline:, position: 1) }
    let!(:harvest)     { create(:harvest_definition, pipeline:, position: 2) }

    def job_with(settings)
      build(:pipeline_job, pipeline:, destination:, block_settings: settings)
    end

    def runs(definition, input: 'fresh', pages: nil)
      { definition.id.to_s => { 'run' => true, 'input' => input, 'pages' => pages } }
    end

    def skips(definition)
      { definition.id.to_s => { 'run' => false, 'input' => 'fresh' } }
    end

    describe 'harvest_definitions_to_run' do
      it 'is derived from the block settings so existing readers keep working' do
        job = job_with(skips(pre_zero)
                         .merge(runs(pre_one, input: 'extraction_job:987'))
                         .merge(runs(harvest)))
        job.save!

        expect(job.harvest_definitions_to_run).to eq [pre_one.id.to_s, harvest.id.to_s]
      end

      it 'is left alone when a caller posts the flat fields instead' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    harvest_definitions_to_run: [pre_zero.id.to_s])

        expect(job.harvest_definitions_to_run).to eq [pre_zero.id.to_s]
        expect(job.run_settings.run?(pre_zero.id)).to be true
        expect(job.run_settings.run?(pre_one.id)).to be false
      end
    end

    describe 'validation of the chain inputs' do
      it 'rejects a block whose preceding block is not running and has no input' do
        job = job_with(skips(pre_zero).merge(runs(pre_one)).merge(runs(harvest)))

        expect(job).not_to be_valid
        expect(job.errors[:block_settings].join).to include 'needs an input'
      end

      it 'rejects a nominated run that has no pre-processed data' do
        job = job_with(skips(pre_zero)
                         .merge(runs(pre_one, input: 'preprocess_output:999'))
                         .merge(runs(harvest)))

        expect(job).not_to be_valid
        expect(job.errors[:block_settings].join).to include 'no pre-processed data'
      end

      it 'accepts an existing extraction instead' do
        job = job_with(skips(pre_zero)
                         .merge(runs(pre_one, input: 'extraction_job:987'))
                         .merge(runs(harvest)))

        expect(job).to be_valid
      end

      it 'accepts the default input when the preceding block is running' do
        expect(job_with(runs(pre_zero).merge(runs(pre_one)).merge(runs(harvest)))).to be_valid
      end

      it 'accepts nominated data that exists' do
        source = create(:pipeline_job, pipeline:, destination:)
        allow(PreProcess::Output).to receive(:pipeline_job_ids_with_output).with(0).and_return([source.id])

        job = job_with(skips(pre_zero)
                         .merge(runs(pre_one, input: "preprocess_output:#{source.id}"))
                         .merge(runs(harvest)))

        expect(job).to be_valid
      end
    end

    # A run covers one unbroken stretch of the chain. A block only exists to feed the
    # one after it, so skipping one and running the next leaves the next with nothing to
    # read - but starting late and stopping early are both fine.
    describe 'validation that the chain has no gaps' do
      it 'rejects a run that skips a block and runs a later one' do
        job = job_with(runs(pre_zero).merge(skips(pre_one)).merge(runs(harvest)))

        expect(job).not_to be_valid
        expect(job.errors[:block_settings].join).to include "#{pre_one.source_id} must run too"
      end

      it 'accepts a run that stops early' do
        expect(job_with(runs(pre_zero).merge(runs(pre_one)).merge(skips(harvest)))).to be_valid
      end

      it 'accepts running only the first block, to prepare data for later' do
        expect(job_with(runs(pre_zero).merge(skips(pre_one)).merge(skips(harvest)))).to be_valid
      end

      it 'accepts a run that skips only leading blocks' do
        job = job_with(skips(pre_zero)
                         .merge(runs(pre_one, input: 'extraction_job:987'))
                         .merge(runs(harvest)))

        expect(job).to be_valid
      end

      it 'accepts a run of nothing at all' do
        expect(job_with(skips(pre_zero).merge(skips(pre_one)).merge(skips(harvest)))).to be_valid
      end
    end

    describe '#pages_for' do
      it 'is the limit set on that block' do
        job = job_with(runs(pre_zero, pages: 5).merge(runs(pre_one)).merge(runs(harvest, pages: 2)))

        expect(job.pages_for(pre_zero)).to eq 5
        expect(job.pages_for(harvest)).to eq 2
      end

      it 'is nil for a block left on every available page' do
        job = job_with(runs(pre_zero).merge(runs(pre_one)).merge(runs(harvest)))

        expect(job.pages_for(pre_one)).to be_nil
      end

      it 'treats an empty or zero field as every available page' do
        job = job_with(runs(pre_zero, pages: '').merge(runs(pre_one, pages: '0')).merge(runs(harvest)))

        expect(job.pages_for(pre_zero)).to be_nil
        expect(job.pages_for(pre_one)).to be_nil
      end

      # The API and automation paths still post a single page limit for the whole run.
      it 'falls back to the job-wide limit for callers posting the flat fields' do
        job = create(:pipeline_job, pipeline:, destination:, page_type: 'set_number', pages: 3,
                                    harvest_definitions_to_run: [pre_zero.id.to_s])

        expect(job.pages_for(pre_zero)).to eq 3
        expect(job.pages_for(harvest)).to eq 3
      end

      it 'ignores the job-wide limit when it is for all available pages' do
        job = create(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages', pages: 3,
                                    harvest_definitions_to_run: [pre_zero.id.to_s])

        expect(job.pages_for(pre_zero)).to be_nil
      end
    end

    describe '#preprocess_source_job_id' do
      it 'is the job itself when the block runs on its own chain output' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: runs(pre_zero).merge(runs(pre_one)).merge(runs(harvest)))

        expect(job.preprocess_source_job_id(pre_one)).to eq job.id
      end

      it 'is the nominated run when the block reuses earlier data' do
        source = create(:pipeline_job, pipeline:, destination:)
        allow(PreProcess::Output).to receive(:pipeline_job_ids_with_output).with(0).and_return([source.id])

        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: skips(pre_zero)
                                      .merge(runs(pre_one, input: "preprocess_output:#{source.id}"))
                                      .merge(runs(harvest)))

        expect(job.preprocess_source_job_id(pre_one)).to eq source.id
      end

      it 'resolves latest to the most recent other run with output at that position' do
        older = create(:pipeline_job, pipeline:, destination:, created_at: 2.days.ago)
        newer = create(:pipeline_job, pipeline:, destination:, created_at: 1.day.ago)
        allow(PreProcess::Output).to receive(:pipeline_job_ids_with_output).with(0)
                                                                          .and_return([older.id, newer.id])

        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: skips(pre_zero)
                                      .merge(runs(pre_one, input: 'preprocess_output:latest'))
                                      .merge(runs(harvest)))

        expect(job.preprocess_source_job_id(pre_one)).to eq newer.id
      end
    end

    describe '#existing_extraction_job_for' do
      let(:extraction_job) { create(:extraction_job, extraction_definition: harvest.extraction_definition) }

      it 'is the nominated extraction job for that block only' do
        job = create(:pipeline_job, pipeline:, destination:,
                                    block_settings: runs(pre_zero)
                                      .merge(runs(pre_one))
                                      .merge(runs(harvest, input: "extraction_job:#{extraction_job.id}")))

        expect(job.existing_extraction_job_for(harvest)).to eq extraction_job
        expect(job.existing_extraction_job_for(pre_zero)).to be_nil
      end

      it 'falls back to the job-wide extraction_job for callers posting the flat fields' do
        job = create(:pipeline_job, pipeline:, destination:, extraction_job:,
                                    harvest_definitions_to_run: [harvest.id.to_s])

        expect(job.existing_extraction_job_for(harvest)).to eq extraction_job
      end

      it 'is nil for an enrichment, which always extracts from the destination API' do
        enrichment = create(:harvest_definition, :enrichment, pipeline:)
        job = create(:pipeline_job, pipeline:, destination:, extraction_job:,
                                    harvest_definitions_to_run: [enrichment.id.to_s])

        expect(job.existing_extraction_job_for(enrichment)).to be_nil
      end
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

    it 'steps over a block that this run is not configured to run' do
      allow(HarvestWorker).to receive(:perform_async_with_priority)
      harvest = create(:harvest_definition, pipeline:, position: 2)
      job = create(:pipeline_job, pipeline:, destination:,
                                  harvest_definitions_to_run: [pre_zero.id.to_s, harvest.id.to_s])

      expect do
        job.advance_to_next_block(pre_zero)
      end.to change { job.harvest_jobs.where(harvest_definition: harvest).count }.by(1)

      expect(job.harvest_jobs.where(harvest_definition: pre_one)).to be_empty

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
