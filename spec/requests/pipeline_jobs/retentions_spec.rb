# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PipelineJobs::Retentions' do
  let(:user)         { create(:user) }
  let(:pipeline)     { create(:pipeline) }
  let(:pipeline_job) { create(:pipeline_job, pipeline:) }

  before { sign_in user }

  describe '#create' do
    it 'retains the run' do
      post pipeline_pipeline_job_retention_path(pipeline, pipeline_job)

      expect(pipeline_job.reload.retained_at).to be_present
      expect(response.parsed_body).to eq('retained' => true)
    end
  end

  describe '#destroy' do
    it 'stops retaining the run' do
      pipeline_job.update(retained_at: Time.zone.now)

      delete pipeline_pipeline_job_retention_path(pipeline, pipeline_job)

      expect(pipeline_job.reload.retained_at).to be_nil
      expect(response.parsed_body).to eq('retained' => false)
    end
  end
end
