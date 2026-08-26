# frozen_string_literal: true

require 'rails_helper'

# Doubles rather than records: a report works its status out from the four stages beneath
# it, and a job's is an enum, so neither can simply be told to be errored. What this
# helper does with the word is all that is being asked about.
RSpec.describe JobStatusHelper do
  describe '#job_status_with_icon' do
    let(:job) { instance_double(PipelineJob, status: 'queued') }

    def report_with(status)
      instance_double(HarvestReport, status:)
    end

    it 'names the status and marks it with its icon' do
      expect(helper.job_status_with_icon(report_with('completed'), job))
        .to include 'Completed', 'bi-check-circle-fill'
    end

    it 'colours a completed job as the good result it is' do
      expect(helper.job_status_with_icon(report_with('completed'), job)).to include 'text-success'
    end

    it 'colours an errored job as the one worth acting on' do
      expect(helper.job_status_with_icon(report_with('errored'), job))
        .to include 'text-danger', 'bi-exclamation-triangle-fill'
    end

    # Neither is a result, so neither earns a colour of its own.
    it 'leaves a running job grey' do
      expect(helper.job_status_with_icon(report_with('running'), job))
        .to include 'text-secondary', 'bi-play-circle-fill'
    end

    it 'reads the job itself when there is no report yet' do
      expect(helper.job_status_with_icon(nil, job)).to include 'Queued', 'bi-hourglass-split'
    end

    it 'still marks a status it does not know' do
      expect(helper.job_status_with_icon(nil, instance_double(PipelineJob, status: 'napping')))
        .to include 'Napping', 'bi-question-circle'
    end
  end
end
