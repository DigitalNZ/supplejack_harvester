# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobsHelper do
  describe '#job_status_text' do
    it 'returns Waiting in queue... for queued jobs' do
      queued_job = create(:extraction_job)
      expect(job_status_text(queued_job)).to eq 'Waiting in queue...'
    end

    it 'returns Running full job... when running a full job if ExtractionJob' do
      full_running_job = create(:extraction_job, status: 'running')
      expect(job_status_text(full_running_job)).to eq 'Running full job...'
    end

    it 'returns Running sample job... when running a sample job' do
      sample_running_job = create(:extraction_job, kind: 'sample', status: 'running')
      expect(job_status_text(sample_running_job)).to eq 'Running sample job...'
    end

    it 'returns An error occured when an error occured' do
      errored_job = create(:extraction_job, status: 'errored')
      expect(job_status_text(errored_job)).to eq 'An error occured'
    end

    it 'returns Cancelled when a job is cancelled' do
      cancelled_job = create(:extraction_job, status: 'cancelled')
      expect(job_status_text(cancelled_job)).to eq 'Cancelled'
    end

    it 'returns Completed when a job is completed' do
      completed_job = create(:extraction_job, status: 'completed')
      expect(job_status_text(completed_job)).to eq 'Completed'
    end
  end

  describe '#job_start_time' do
    subject(:job) { ExtractionJob.new(start_time: Time.zone.now, end_time: 1.minute.from_now) }

    it 'returns - if start_time is empty' do
      job.start_time = nil
      expect(job_start_time(job)).to eq '-'
    end

    it 'returns the formatted date if start_time is set' do
      expect(job_start_time(job)).to eq job.start_time.to_fs(:light)
    end
  end

  describe '#job_end_time' do
    subject(:job) { ExtractionJob.new(start_time: Time.zone.now, end_time: 1.minute.from_now) }

    it 'returns - if end_time is empty' do
      job.end_time = nil
      expect(job_end_time(job)).to eq '-'
    end

    it 'returns the formatted date if end_time is set' do
      expect(job_end_time(job)).to eq job.end_time.to_fs(:light)
    end
  end

  describe '#job_duration' do
    subject(:job) { ExtractionJob.new(start_time: Time.zone.now, end_time: 1.minute.from_now) }

    it 'returns a human readable duration if start and end time are set' do
      expect(job_duration(job)).to eq ActiveSupport::Duration.build(job.duration_seconds).inspect
    end

    it 'returns - if start_time is nil' do
      job.start_time = nil
      expect(job_duration(job)).to eq '-'
    end

    it 'returns - if end_time is nil' do
      job.end_time = nil
      expect(job_duration(job)).to eq '-'
    end
  end

  describe '#job_duration_seconds' do
    subject(:job) { ExtractionJob.new(start_time: Time.zone.now, end_time: 1.minute.from_now) }

    it 'returns a human readable duration if start and end time are set' do
      expect(job_duration_seconds(job.duration_seconds)).to eq(
        ActiveSupport::Duration.build(job.duration_seconds).inspect
      )
    end

    it 'returns - if start_time is nil' do
      job.start_time = nil
      expect(job_duration_seconds(job.duration_seconds)).to eq '-'
    end

    it 'returns - if end_time is nil' do
      job.end_time = nil
      expect(job_duration_seconds(job.duration_seconds)).to eq '-'
    end
  end
end
