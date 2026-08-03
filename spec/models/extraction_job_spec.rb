# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionJob do
  subject { create(:extraction_job, extraction_definition:) }

  let(:pipeline) { create(:pipeline, name: 'National Library of New Zealand') }
  let(:extraction_definition) { create(:extraction_definition, pipeline:) }

  describe '#name' do
    it 'autogenerates a sensible name' do
      expect(subject.name).to eq "#{subject.id}_full-extraction"
    end
  end

  describe 'status checks' do
    described_class::STATUSES.each do |status|
      it "defines the check #{status}?" do
        subject.status = status
        expect(subject.send("#{status}?")).to be true
        subject.status = described_class::STATUSES.without(status).sample
        expect(subject.send("#{status}?")).to be false
      end

      it "defines a way to update the status with #{status}!" do
        subject.status = status
        expect(subject.send("#{status}!")).to be true
        subject.reload
        expect(subject.send("#{status}?")).to be true
      end
    end
  end

  describe 'kind checks' do
    described_class.kinds.each_key do |kind|
      it "defines the check is_#{kind}?" do
        subject.kind = kind
        expect(subject.send("is_#{kind}?")).to be true
        subject.kind = described_class.kinds.keys.without(kind).sample
        expect(subject.send("is_#{kind}?")).to be false
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:extraction_definition).with_message('must exist') }

    it 'does not allow an end date to be before a start date' do
      subject.start_time = Time.zone.now
      subject.end_time   = 1.day.ago
      expect(subject).not_to be_valid
    end
  end

  describe '#associations' do
    it 'belongs to an Extraction Definition' do
      expect(subject.extraction_definition).to be_a(ExtractionDefinition)
    end
  end

  describe '#extraction_folder' do
    it 'returns the path for where the extractions are kept' do
      expect(subject.extraction_folder).to eq("#{Rails.root.join('extractions')}/#{Rails.env}/#{subject.created_at.strftime('%Y-%m-%d_%H-%M-%S')}_-_#{subject.id}")
    end
  end

  describe '#create_folder' do
    it 'creates a folder at the Extractions Path' do
      expect(File.exist?(subject.extraction_folder)).to be true
    end
  end

  describe '#delete_folder' do
    it 'deletes a folder at the extractions path' do
      expect(File.exist?(subject.extraction_folder)).to be true

      subject.delete_folder

      expect(File.exist?(subject.extraction_folder)).to be false
    end

    it 'does nothing if the folder does not exist' do
      expect(File.exist?(subject.extraction_folder)).to be true

      subject.delete_folder

      expect(File.exist?(subject.extraction_folder)).to be false

      expect { subject.delete_folder }.not_to raise_error
    end
  end

  describe '#documents' do
    it 'returns an Extraction::Documents object' do
      expect(subject.documents).to be_a(Extraction::Documents)
    end
  end

  describe '#timestamps' do
    it 'can record when the job was started' do
      subject.update(start_time: Time.zone.now)

      expect(subject.start_time).to be_a(ActiveSupport::TimeWithZone)
    end

    it 'can record when the job was finished' do
      subject.update(end_time: 1.day.from_now)

      expect(subject.end_time).to be_a(ActiveSupport::TimeWithZone)
    end

    it 'returns the number of seconds that the job has been running for' do
      subject.update(start_time: '2023-03-20 11:00:00', end_time: '2023-03-20 11:05:00')
      subject.reload
      expect(subject.duration_seconds).to eq 300
    end
  end

  describe '#extraction_folder_size_in_bytes' do
    let(:extraction_definition) { create(:extraction_definition, base_url: 'http://google.com', paginated: true) }

    before do
      (1...5).each do |page|
        request = create(:request, extraction_definition:)
        create(:parameter, name: 'url_param', content: 'url_value', kind: 'query', request:)
        create(:parameter, name: 'per_page', content: '50', kind: 'query', request:)
        create(:parameter, name: 'page', content: page, kind: 'query', request:)

        stub_request(:get, 'http://google.com').with(
          query: { 'page' => page, 'per_page' => 50, 'url_param' => 'url_value' },
          headers: fake_json_headers
        ).and_return(fake_response("figshare_#{page}"))
      end
    end

    it 'returns the size of the extraction folder in bytes' do
      Extraction::Execution.new(subject, extraction_definition).call

      expect(subject.extraction_folder_size_in_bytes).to eq 46334
    end
  end

  describe '#finished?' do
    let(:finished_ej) { create(:extraction_job, status: 'completed') }
    let(:unfinished_ej) { create(:extraction_job, status: 'running') }

    it 'returns true if the job has finished' do
      expect(finished_ej.finished?).to be true
    end

    it 'returns false if the job has not finished' do
      expect(unfinished_ej.finished?).to be false
    end
  end

  describe '#statuses' do
    statuses = { queued: 0, cancelled: 1, running: 2, completed: 3, errored: 4 }

    statuses.each do |key, value|
      it "can be #{key}" do
        expect(described_class.new(status: value).status).to eq(key.to_s)
      end
    end
  end

  describe '#kinds' do
    described_class.kinds.each do |key, value|
      it "can be #{key}" do
        expect(described_class.new(kind: value).kind).to eq(key.to_s)
      end
    end
  end

  describe '#finished?' do
    let(:finished_ej) { create(:extraction_job, status: 'completed') }
    let(:unfinished_ej) { create(:extraction_job, status: 'running') }

    it 'returns true if the job has finished' do
      expect(finished_ej.finished?).to be true
    end

    it 'returns false if the job has not finished' do
      expect(unfinished_ej.finished?).to be false
    end
  end

  describe '#purged?' do
    it 'is false when the data is still on disk' do
      expect(subject.purged?).to be false
    end

    it 'is true once purged_at is stamped' do
      subject.update(purged_at: Time.zone.now)

      expect(subject.purged?).to be true
    end
  end

  describe '#purge!' do
    it 'deletes the extraction folder' do
      FileUtils.mkdir_p("#{subject.extraction_folder}/1")
      File.write("#{subject.extraction_folder}/1/page.json", '{}')

      subject.purge!

      expect(Dir.exist?(subject.extraction_folder)).to be false
    end

    it 'stamps purged_at' do
      subject.purge!

      expect(subject.reload.purged_at).to be_present
    end

    it 'stamps purged_at even when the folder is already gone' do
      FileUtils.rm_rf(subject.extraction_folder)

      subject.purge!

      expect(subject.reload.purged_at).to be_present
    end

    it 'keeps the row and its harvest job' do
      harvest_job = create(:harvest_job, extraction_job: subject)

      subject.purge!

      expect(described_class.find_by(id: subject.id)).to be_present
      expect(HarvestJob.find_by(id: harvest_job.id)).to be_present
    end
  end

  describe '.purge_candidates' do
    let(:policy) do
      ExtractionLifecyclePolicy.new(
        dry_run: false, batch_limit: 100, min_age_months: 1,
        keep_latest: 2, max_age_months: 6, excluded_extraction_definition_ids: []
      )
    end

    # keep_latest is 2 here so a handful of jobs exercises the index clause.
    def job_created(time_ago, **attributes)
      create(:extraction_job, extraction_definition:, status: 'completed',
                              created_at: time_ago, **attributes)
    end

    it 'keeps everything younger than min_age_months' do
      recent = job_created(2.days.ago)

      expect(described_class.purge_candidates(policy)).not_to include(recent)
    end

    it 'keeps a young job even though it ranks past keep_latest' do
      job_created(1.day.ago)
      job_created(2.days.ago)
      young_but_over_keep_latest = job_created(3.days.ago)

      expect(described_class.purge_candidates(policy)).not_to include(young_but_over_keep_latest)
    end

    it 'ranks jobs separately per extraction definition' do
      other_definition = create(:extraction_definition)

      own_newest = job_created(5.months.ago)
      job_created(6.months.ago)
      job_created(7.months.ago)

      other_newest = create(:extraction_job, extraction_definition: other_definition,
                                              status: 'completed', created_at: 2.months.ago)
      create(:extraction_job, extraction_definition: other_definition, status: 'completed', created_at: 3.months.ago)
      create(:extraction_job, extraction_definition: other_definition, status: 'completed', created_at: 4.months.ago)

      candidates = described_class.purge_candidates(policy)

      expect(candidates).not_to include(own_newest)
      expect(candidates).not_to include(other_newest)
    end

    it 'keeps the newest keep_latest jobs even when they are old' do
      newest = job_created(2.months.ago)
      job_created(3.months.ago)
      job_created(4.months.ago)

      expect(described_class.purge_candidates(policy)).not_to include(newest)
    end

    it 'keeps the job ranked exactly at keep_latest' do
      job_created(2.months.ago)
      at_boundary = job_created(3.months.ago)
      job_created(4.months.ago)

      expect(described_class.purge_candidates(policy)).not_to include(at_boundary)
    end

    it 'purges old jobs beyond the newest keep_latest' do
      job_created(2.months.ago)
      job_created(3.months.ago)
      oldest = job_created(4.months.ago)

      expect(described_class.purge_candidates(policy)).to include(oldest)
    end

    it 'purges jobs past max_age_months even at index 1' do
      ancient = job_created(7.months.ago)

      expect(described_class.purge_candidates(policy)).to include(ancient)
    end

    it 'ignores already-purged jobs when ranking' do
      job_created(2.months.ago, purged_at: Time.zone.now)
      job_created(3.months.ago, purged_at: Time.zone.now)
      third = job_created(4.months.ago)

      # It is now the only job that still has data, so it ranks 1 and survives
      # even though two older-ranked rows exist.
      expect(described_class.purge_candidates(policy)).not_to include(third)
    end

    it 'excludes jobs that have already been purged' do
      purged = job_created(7.months.ago, purged_at: Time.zone.now)

      expect(described_class.purge_candidates(policy)).not_to include(purged)
    end

    it 'excludes queued and running jobs' do
      queued = job_created(7.months.ago, status: 'queued')
      running = job_created(7.months.ago, status: 'running')

      candidates = described_class.purge_candidates(policy)

      expect(candidates).not_to include(queued)
      expect(candidates).not_to include(running)
    end

    it 'excludes jobs an unfinished harvest job is using' do
      job = job_created(7.months.ago)
      create(:harvest_job, extraction_job: job, status: 'running')

      expect(described_class.purge_candidates(policy)).not_to include(job)
    end

    it 'excludes jobs an unfinished pipeline job is using' do
      job = job_created(7.months.ago)
      create(:pipeline_job, extraction_job: job, status: 'running')

      expect(described_class.purge_candidates(policy)).not_to include(job)
    end

    it 'excludes jobs a created-but-not-started pipeline job is using' do
      job = job_created(7.months.ago)
      # A pipeline job has no status until PipelineWorker picks it up.
      create(:pipeline_job, extraction_job: job)

      expect(described_class.purge_candidates(policy)).not_to include(job)
    end

    it 'excludes extraction definitions on the escape-hatch list' do
      job = job_created(7.months.ago)
      excluded_policy = ExtractionLifecyclePolicy.new(
        dry_run: false, batch_limit: 100, min_age_months: 1, keep_latest: 2,
        max_age_months: 6, excluded_extraction_definition_ids: [extraction_definition.id]
      )

      expect(described_class.purge_candidates(excluded_policy)).not_to include(job)
    end

    it 'keeps a transformation definition preview past the index cutoff' do
      job_created(2.months.ago)
      job_created(3.months.ago)
      pinned = job_created(4.months.ago)
      create(:transformation_definition, extraction_job: pinned)

      expect(described_class.purge_candidates(policy)).not_to include(pinned)
    end

    it 'purges a transformation definition preview past max_age_months' do
      pinned = job_created(7.months.ago)
      create(:transformation_definition, extraction_job: pinned)

      expect(described_class.purge_candidates(policy)).to include(pinned)
    end

    it 'exposes the extraction index on each candidate' do
      job_created(2.months.ago)
      job_created(3.months.ago)
      job_created(4.months.ago)

      expect(described_class.purge_candidates(policy).first.extraction_index).to eq 3
    end

    it 'caps the batch at batch_limit, oldest first' do
      job_created(5.months.ago)
      oldest = job_created(7.months.ago)
      capped = ExtractionLifecyclePolicy.new(
        dry_run: false, batch_limit: 1, min_age_months: 1, keep_latest: 0,
        max_age_months: 6, excluded_extraction_definition_ids: []
      )

      expect(described_class.purge_candidates(capped)).to contain_exactly(oldest)
    end
  end
end
