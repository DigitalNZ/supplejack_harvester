# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ExtractionJobs', type: :request do
  let(:user)           { create(:user) }
  subject!             { create(:extraction_job, extraction_definition:) }

  let(:pipeline) { create(:pipeline, :ngataonga) }
  let(:harvest_definition) { pipeline.harvest }
  let(:extraction_definition) { harvest_definition.extraction_definition }

  before do
    sign_in user
  end

  describe '#show' do
    before do
      # that's to test the display of results
      stub_ngataonga_harvest_requests(extraction_definition)
      ExtractionWorker.new.perform(subject.id)
      get pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition, subject)
    end

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'displays the updated_at of the jobs' do
      subject.reload
      expect(response.body).to include subject.updated_at.to_fs(:verbose)
    end
  end

  describe '#create' do
    describe 'is successful' do
      it 'redirects to the pipeline jobs path' do
        post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition,
                                                                        kind: 'full')
        expect(response).to redirect_to pipeline_jobs_path(pipeline)
      end

      it 'sets a succesful message' do
        post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition,
                                                                        kind: 'full')
        follow_redirect!
        expect(response.body).to include 'Job queued successfuly'
      end

      it 'queues a job' do
        expect(ExtractionWorker).to receive(:perform_async)

        post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition,
                                                                        kind: 'full')
      end
    end

    describe 'is not successful' do
      before do
        expect_any_instance_of(ExtractionJob).to receive(:save).and_return(false)
      end

      it 'redirects to the pipeline jobs path' do
        post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition)

        expect(response).to redirect_to pipeline_jobs_path(pipeline)
      end

      it 'sets a failure message' do
        post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition)
        follow_redirect!
        expect(response.body).to include 'There was an issue launching the job'
      end

      it 'does not queue a job' do
        expect(ExtractionWorker).not_to receive(:perform_async)
        post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition)
      end
    end
  end

  describe '#destroy' do
    context 'when the destroy is successful' do
      it 'deletes the job' do
        expect do
          delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition,
                                                                           subject)
        end.to change(ExtractionJob, :count).by(-1)
      end

      it 'redirects to the correct path' do
        delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition,
                                                                           subject)
        expect(response).to redirect_to(pipeline_jobs_path(pipeline))
      end

      it 'displays an appropriate flash message' do
        delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition,
                                                                           subject)

        follow_redirect!

        expect(response.body).to include 'Results deleted successfully'
      end
    end

    context 'when the destroy is not successful' do
      before do
        allow_any_instance_of(ExtractionJob).to receive(:destroy).and_return(false)
      end

      it 'does not delete the job' do
        expect do
          delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition,
                                                                           subject)
        end.not_to change(ExtractionJob, :count)
      end

      it 'redirects to the correct path' do
        delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition, subject)

        expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition,
                                                                                                  extraction_definition, subject)
      end

      it 'displays an appropriate flash message' do
        delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition, subject)

        follow_redirect!

        expect(response.body).to include 'There was an issue deleting the results'
      end
    end
  end

  describe '#cancel' do
    context 'when the cancellation is successful' do
      before do
        post cancel_pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition,
                                                                              subject)
      end

      it 'sets the job status to be cancelled' do
        subject.reload
        expect(subject.status).to eq 'cancelled'
      end

      it 'redirects to the correct path' do
        expect(response).to redirect_to pipeline_jobs_path(pipeline)
      end

      it 'displays an appropriate flash message' do
        follow_redirect!

        expect(response.body).to include 'Job cancelled successfully'
      end
    end

    context 'when the cancellation is unsuccessful' do
      before do
        allow_any_instance_of(ExtractionJob).to receive(:cancelled!).and_return(false)
        post cancel_pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition, extraction_definition,
                                                                              subject)
      end

      it 'does not set the job status to be cancelled' do
        subject.reload
        expect(subject.status).not_to eq 'cancelled'
      end

      it 'redirects to the correct path' do
        expect(response).to redirect_to pipeline_jobs_path(pipeline)
      end

      it 'displays an appropriate flash message' do
        follow_redirect!

        expect(response.body).to include 'There was an issue cancelling the job'
      end
    end
  end
end
