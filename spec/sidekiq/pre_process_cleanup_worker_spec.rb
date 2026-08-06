# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreProcessCleanupWorker, type: :worker do
  let(:pipeline) { create(:pipeline) }

  let(:policy_attributes) do
    { dry_run: false, keep_latest: 2, min_age_months: 1, max_age_months: 6 }
  end

  before do
    allow(PreProcessRetentionPolicy).to receive(:load).and_return(PreProcessRetentionPolicy.new(policy_attributes))
  end

  describe '#perform' do
    # Real files, not DB rows - not rolled back between examples. Tests that
    # stub the removal to fail deliberately leave folders behind; without
    # this they'd leak into (and be re-attempted by) later examples.
    after { FileUtils.rm_rf(PreProcess::Output::FOLDER) }

    def preprocess_folder(pipeline_job_id)
      folder = PreProcess::Output.folder(pipeline_job_id, 1)
      FileUtils.mkdir_p(folder)
      File.write("#{folder}/preprocess__000000001.json", '{}')
      PreProcess::Output.job_folder(pipeline_job_id)
    end

    def run_with_output(pipeline, created_at:, status: 'completed')
      pipeline_job = create(:pipeline_job, pipeline:, status:, created_at:)
      preprocess_folder(pipeline_job.id)
    end

    it 'keeps the newest keep_latest runs and sweeps the rest' do
      oldest = run_with_output(pipeline, created_at: 5.days.ago)
      middle = run_with_output(pipeline, created_at: 4.days.ago)
      newest = run_with_output(pipeline, created_at: 3.days.ago)

      described_class.new.perform

      expect(Dir.exist?(oldest)).to be false
      expect(Dir.exist?(middle)).to be true
      expect(Dir.exist?(newest)).to be true
    end

    it 'ranks runs per pipeline, not globally' do
      other_pipeline = create(:pipeline)
      old_a = run_with_output(pipeline, created_at: 5.days.ago)
      kept_a = run_with_output(pipeline, created_at: 4.days.ago)
      kept_b = run_with_output(pipeline, created_at: 3.days.ago)
      old_c = run_with_output(other_pipeline, created_at: 6.days.ago)
      kept_c = run_with_output(other_pipeline, created_at: 2.days.ago)
      kept_d = run_with_output(other_pipeline, created_at: 1.day.ago)

      described_class.new.perform

      expect(Dir.exist?(old_a)).to be false
      expect(Dir.exist?(old_c)).to be false
      [kept_a, kept_b, kept_c, kept_d].each do |folder|
        expect(Dir.exist?(folder)).to be true
      end
    end

    it 'keeps an out-ranked run that might still be writing' do
      still_writing = run_with_output(pipeline, created_at: 2.hours.ago, status: 'running')
      run_with_output(pipeline, created_at: 1.hour.ago)
      run_with_output(pipeline, created_at: 30.minutes.ago)

      described_class.new.perform

      expect(Dir.exist?(still_writing)).to be true
    end

    it 'sweeps an out-ranked unfinished run once it is older than a day' do
      # A crashed run stays "running" forever and a preprocess-only pipeline
      # never completes; the one-day writing window lets keep-N reclaim both.
      abandoned = run_with_output(pipeline, created_at: 3.days.ago, status: 'running')
      run_with_output(pipeline, created_at: 2.days.ago)
      run_with_output(pipeline, created_at: 1.day.ago)

      described_class.new.perform

      expect(Dir.exist?(abandoned)).to be false
    end

    it 'sweeps an orphan folder older than a day' do
      folder = preprocess_folder(999_999)
      FileUtils.touch(folder, mtime: 2.days.ago.to_time)

      described_class.new.perform

      expect(Dir.exist?(folder)).to be false
    end

    it 'keeps a freshly written orphan folder' do
      folder = preprocess_folder(999_998)

      described_class.new.perform

      expect(Dir.exist?(folder)).to be true
    end

    it 'sweeps a folder whose pipeline job row has since been deleted' do
      pipeline_job = create(:pipeline_job, pipeline:, status: 'completed', created_at: 3.months.ago)
      folder = preprocess_folder(pipeline_job.id)
      pipeline_job.destroy
      FileUtils.touch(folder, mtime: 2.days.ago.to_time)

      described_class.new.perform

      expect(Dir.exist?(folder)).to be false
    end

    it 'reports how many folders it swept' do
      run_with_output(pipeline, created_at: 5.days.ago)
      run_with_output(pipeline, created_at: 4.days.ago)
      run_with_output(pipeline, created_at: 3.days.ago)
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(Rails.logger).to have_received(:info)
        .with(a_string_matching(/finished swept=1 examined=1 dry_run=false\z/))
    end

    context 'when dry_run is on' do
      let(:policy_attributes) { super().merge(dry_run: true) }

      it 'sweeps nothing' do
        oldest = run_with_output(pipeline, created_at: 5.days.ago)
        run_with_output(pipeline, created_at: 4.days.ago)
        run_with_output(pipeline, created_at: 3.days.ago)

        described_class.new.perform

        expect(Dir.exist?(oldest)).to be true
      end

      it 'reports what it would sweep, not that anything was swept' do
        run_with_output(pipeline, created_at: 5.days.ago)
        run_with_output(pipeline, created_at: 4.days.ago)
        run_with_output(pipeline, created_at: 3.days.ago)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(a_string_matching(/finished would_sweep=1 dry_run=true\z/))
      end
    end

    context 'when a folder cannot be removed' do
      let!(:folder) { run_with_output(pipeline, created_at: 5.days.ago) }

      # Keyed on the exact path, not stubbed wholesale, so the `after` hook's
      # own FileUtils.rm_rf (which rm_r underneath) can still clean up.
      before do
        run_with_output(pipeline, created_at: 4.days.ago)
        run_with_output(pipeline, created_at: 3.days.ago)
        allow(FileUtils).to receive(:rm_r).and_wrap_original do |original, path, **kwargs|
          raise Errno::EACCES if path == folder

          original.call(path, **kwargs)
        end
      end

      it 'leaves the folder in place so the next run retries it' do
        described_class.new.perform

        expect(Dir.exist?(folder)).to be true
      end

      it 'does not count the failed folder as swept' do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info)
          .with(a_string_matching(/finished swept=0 examined=1 dry_run=false\z/))
      end

      it 'notifies Airbrake of the failure' do
        allow(Airbrake).to receive(:notify)

        described_class.new.perform

        expect(Airbrake).to have_received(:notify).with(instance_of(Errno::EACCES))
      end
    end

    it 'does not abort the run (and lose the summary log) when a folder vanishes mid-sweep' do
      preprocess_folder(999_997)
      allow(File).to receive(:mtime).and_raise(Errno::ENOENT)
      allow(Rails.logger).to receive(:info)

      expect { described_class.new.perform }.not_to raise_error

      expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[preprocess_cleanup\] finished /))
    end
  end
end
