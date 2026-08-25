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

    it 'returns empty string if start_time is nil' do
      job.start_time = nil
      expect(job_duration(job)).to eq ''
    end

    it 'returns empty string if end_time is nil' do
      job.end_time = nil
      expect(job_duration(job)).to eq ''
    end
  end

  describe '#job_duration_seconds_short' do
    it 'reads in minutes and seconds' do
      expect(job_duration_seconds_short(597)).to eq '9m 57s'
    end

    it 'reads in seconds alone under a minute' do
      expect(job_duration_seconds_short(5)).to eq '5s'
    end

    # At that length the seconds are noise, and the column has a start time to fit too.
    it 'leaves the seconds out of an hour-long run' do
      expect(job_duration_seconds_short(9659)).to eq '2h 40m'
    end

    it 'says nothing lasted no time at all' do
      expect(job_duration_seconds_short(0)).to eq '0s'
    end
  end

  describe '#job_started_and_duration' do
    let(:report) { create(:harvest_report) }

    it 'joins when the job started to how long it ran' do
      # The report works its duration out from the times it holds, so this is 9m 57s of it.
      report.update(extraction_start_time: Time.zone.local(2026, 8, 21, 3, 44),
                    extraction_end_time: Time.zone.local(2026, 8, 21, 3, 53, 57))

      expect(helper.job_started_and_duration(report, report.pipeline_job)).to eq '03:44 21/08/26 · 9m 57s'
    end

    # A queued job has neither, and a running one has no duration yet.
    it 'leaves the separator off when there is only one of them' do
      job = create(:pipeline_job, start_time: Time.zone.local(2026, 8, 21, 3, 44))

      expect(helper.job_started_and_duration(nil, job)).to eq '03:44 21/08/26'
    end

    it 'is empty for a job that has not started' do
      expect(helper.job_started_and_duration(nil, create(:pipeline_job, start_time: nil))).to eq ''
    end
  end

  describe '#job_duration_seconds' do
    subject(:job) { ExtractionJob.new(start_time: Time.zone.now, end_time: 1.minute.from_now) }

    it 'returns a human readable duration if start and end time are set' do
      expect(job_duration_seconds(job.duration_seconds)).to eq(
        ActiveSupport::Duration.build(job.duration_seconds).inspect
      )
    end

    it 'returns empty string if start_time is nil' do
      job.start_time = nil
      expect(job_duration_seconds(job.duration_seconds)).to eq ''
    end

    it 'returns empty string if end_time is nil' do
      job.end_time = nil
      expect(job_duration_seconds(job.duration_seconds)).to eq ''
    end
  end

  describe '#jobs_filter_url' do
    let(:pipeline) { create(:pipeline) }

    it 'generates the correct jobs filter URL' do
      expected_url = "#{pipeline_pipeline_jobs_path(pipeline)}?pipeline_id=#{pipeline.id}"

      expect(helper.jobs_filter_url(pipeline)).to eq(expected_url)
    end
  end

  describe '#job_source_line' do
    let(:destination) { create(:destination, name: 'Production API') }

    it 'names the destination and whoever ran the job' do
      job = create(:pipeline_job, destination:, launched_by: create(:user, username: 'ting'))

      expect(helper.job_source_line(job)).to eq 'Production API · Run by ting'
    end

    it 'links to the schedule that ran the job' do
      schedule = create(:schedule, destination:, automation_template: create(:automation_template))
      job = create(:pipeline_job, destination:, schedule:, launched_by: nil)

      expect(helper.job_source_line(job)).to eq(
        "Production API · Run by <a href=\"#{schedule_path(schedule)}\">Schedule</a>"
      )
    end

    it 'is the destination alone when nobody is recorded as running the job' do
      job = create(:pipeline_job, destination:, launched_by: nil)

      expect(helper.job_source_line(job)).to eq 'Production API'
    end

    it 'escapes a username rather than trusting it' do
      job = create(:pipeline_job, destination:, launched_by: create(:user, username: '<b>ting</b>'))

      expect(helper.job_source_line(job)).to eq 'Production API · Run by &lt;b&gt;ting&lt;/b&gt;'
    end
  end

  describe '#extraction_end_reason' do
    let(:harvest_job) { create(:harvest_job) }
    let(:report) { create(:harvest_report, harvest_job:, pipeline_job: harvest_job.pipeline_job) }

    it 'returns the stop condition reason when present' do
      harvest_job.extraction_job.update!(stop_condition_type: 'user', stop_condition_name: 'Set number reached')

      expect(helper.extraction_end_reason(report)).to eq('User stop condition: Set number reached')
    end

    it 'returns extraction error message when present' do
      harvest_job.extraction_job.update!(error_message: 'Timeout while extracting')

      expect(helper.extraction_end_reason(report)).to eq('Timeout while extracting')
    end

    it 'returns a status-based reason when no stop condition or error exists' do
      report.extraction_completed!

      expect(helper.extraction_end_reason(report)).to eq('Completed')
    end
  end
end
