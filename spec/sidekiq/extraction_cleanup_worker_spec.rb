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
  end
end
