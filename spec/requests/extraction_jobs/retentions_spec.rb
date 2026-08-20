# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ExtractionJobs::Retentions' do
  subject! { create(:extraction_job, extraction_definition:, status: 'completed') }

  let(:user)                  { create(:user) }
  let(:pipeline)              { create(:pipeline, :figshare) }
  let(:harvest_definition)    { pipeline.harvest }
  let(:extraction_definition) { harvest_definition.extraction_definition }

  let(:retention_path) do
    pipeline_harvest_definition_extraction_definition_extraction_job_retention_path(
      pipeline, harvest_definition, extraction_definition, subject
    )
  end

  let(:job_path) do
    pipeline_harvest_definition_extraction_definition_extraction_job_path(
      pipeline, harvest_definition, extraction_definition, subject
    )
  end

  before { sign_in user }

  describe '#create' do
    it 'retains the job and returns to it' do
      post retention_path

      expect(subject.reload.retained_at).to be_present
      expect(response).to redirect_to(job_path)
    end

    it 'refuses a purged job' do
      subject.update(purged_at: Time.zone.now)

      post retention_path

      expect(subject.reload.retained_at).to be_nil
      expect(flash.alert).to eq "This job's data was already removed, so it can't be retained"
    end
  end

  describe '#destroy' do
    it 'stops retaining the job and returns to it' do
      subject.update(retained_at: Time.zone.now)

      delete retention_path

      expect(subject.reload.retained_at).to be_nil
      expect(response).to redirect_to(job_path)
    end
  end
end
