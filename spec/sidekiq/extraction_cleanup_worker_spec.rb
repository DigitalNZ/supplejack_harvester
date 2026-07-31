# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionCleanupWorker, type: :worker do
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) { create(:extraction_definition, pipeline:) }

  let(:policy_attributes) do
    {
      dry_run: false, batch_limit: 100, min_age_months: 1,
      keep_latest: 0, max_age_months: 6, excluded_extraction_definition_ids: []
    }
  end

  let!(:old_job) do
    create(:extraction_job, extraction_definition:, status: 'completed', created_at: 7.months.ago)
  end

  before do
    allow(ExtractionLifecyclePolicy).to receive(:load).and_return(ExtractionLifecyclePolicy.new(policy_attributes))
  end

  describe '#perform' do
    it 'deletes the folder of an expired job' do
      described_class.new.perform

      expect(Dir.exist?(old_job.extraction_folder)).to be false
    end

    it 'stamps purged_at' do
      described_class.new.perform

      expect(old_job.reload.purged_at).to be_present
    end

    it 'leaves a job that is still within the policy alone' do
      recent = create(:extraction_job, extraction_definition:, status: 'completed', created_at: 2.days.ago)

      described_class.new.perform

      expect(recent.reload.purged_at).to be_nil
      expect(Dir.exist?(recent.extraction_folder)).to be true
    end

    context 'when dry_run is on' do
      let(:policy_attributes) { super().merge(dry_run: true) }

      it 'deletes nothing' do
        described_class.new.perform

        expect(Dir.exist?(old_job.extraction_folder)).to be true
      end

      it 'stamps nothing' do
        described_class.new.perform

        expect(old_job.reload.purged_at).to be_nil
      end

      it 'still logs the candidate it would purge' do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(a_string_including("extraction_job=#{old_job.id}"))
      end

      it 'reports how much would be freed, not that anything was purged' do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info)
          .with(a_string_matching(/finished examined=1 would_free_bytes=\d+ dry_run=true/))
      end
    end

    context 'when batch_limit is reached' do
      let(:policy_attributes) { super().merge(batch_limit: 1) }

      it 'purges no more than the limit' do
        create(:extraction_job, extraction_definition:, status: 'completed', created_at: 8.months.ago)

        described_class.new.perform

        expect(ExtractionJob.where.not(purged_at: nil).count).to eq 1
      end
    end

    context 'when a folder cannot be deleted' do
      let!(:other_job) do
        create(:extraction_job, extraction_definition:, status: 'completed', created_at: 8.months.ago)
      end

      before do
        allow_any_instance_of(ExtractionJob).to receive(:purge!).and_wrap_original do |original|
          raise Errno::EACCES if original.receiver.id == other_job.id

          original.call
        end
      end

      it 'leaves that job unpurged so the next run retries it' do
        described_class.new.perform

        expect(other_job.reload.purged_at).to be_nil
      end

      it 'still purges the rest of the batch' do
        described_class.new.perform

        expect(old_job.reload.purged_at).to be_present
      end

      it 'does not count the failed job among what it purged' do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(a_string_matching(/finished purged=1 /))
      end

      it 'notifies Airbrake of the failure' do
        allow(Airbrake).to receive(:notify)

        described_class.new.perform

        expect(Airbrake).to have_received(:notify).with(instance_of(Errno::EACCES))
      end
    end

    describe 'preprocess sweep' do
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

      it 'sweeps output belonging to an old finished pipeline job' do
        pipeline_job = create(:pipeline_job, pipeline:, status: 'completed', created_at: 3.months.ago)
        folder = preprocess_folder(pipeline_job.id)

        described_class.new.perform

        expect(Dir.exist?(folder)).to be false
      end

      it 'keeps output from a recent pipeline job' do
        pipeline_job = create(:pipeline_job, pipeline:, status: 'completed', created_at: 2.days.ago)
        folder = preprocess_folder(pipeline_job.id)

        described_class.new.perform

        expect(Dir.exist?(folder)).to be true
      end

      it 'keeps output from an old pipeline job that is still running' do
        pipeline_job = create(:pipeline_job, pipeline:, status: 'running', created_at: 3.months.ago)
        folder = preprocess_folder(pipeline_job.id)

        described_class.new.perform

        expect(Dir.exist?(folder)).to be true
      end

      it 'sweeps output from a non-terminal job once it clears max_age_cutoff' do
        # Nothing in the app ever moves a PipelineJob to 'errored', so a crashed
        # run stays 'running' forever. max_age_months (6, here) is the backstop
        # that reclaims its output anyway once it's far too old to be real work.
        pipeline_job = create(:pipeline_job, pipeline:, status: 'running', created_at: 7.months.ago)
        folder = preprocess_folder(pipeline_job.id)

        described_class.new.perform

        expect(Dir.exist?(folder)).to be false
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

      it 'reports how many preprocess folders it swept' do
        pipeline_job = create(:pipeline_job, pipeline:, status: 'completed', created_at: 3.months.ago)
        preprocess_folder(pipeline_job.id)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(a_string_matching(/preprocess_swept=1\z/))
      end

      context 'when dry_run is on' do
        let(:policy_attributes) { super().merge(dry_run: true) }

        it 'sweeps nothing' do
          pipeline_job = create(:pipeline_job, pipeline:, status: 'completed', created_at: 3.months.ago)
          folder = preprocess_folder(pipeline_job.id)

          described_class.new.perform

          expect(Dir.exist?(folder)).to be true
        end

        it 'reports what it would sweep, not that anything was swept' do
          pipeline_job = create(:pipeline_job, pipeline:, status: 'completed', created_at: 3.months.ago)
          preprocess_folder(pipeline_job.id)
          allow(Rails.logger).to receive(:info)

          described_class.new.perform

          expect(Rails.logger).to have_received(:info).with(a_string_matching(/preprocess_would_sweep=1\z/))
        end
      end

      context 'when a preprocess folder cannot be removed' do
        let(:pipeline_job) { create(:pipeline_job, pipeline:, status: 'completed', created_at: 3.months.ago) }
        let!(:folder) { preprocess_folder(pipeline_job.id) }

        # Keyed on the exact path, not stubbed wholesale, so the `after` hook's
        # own FileUtils.rm_rf (which rm_r underneath) can still clean up.
        before do
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

          expect(Rails.logger).to have_received(:info).with(a_string_matching(/preprocess_swept=0\z/))
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

        expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[extraction_cleanup\] finished /))
      end
    end
  end
end
