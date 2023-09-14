require 'rails_helper'

RSpec.describe 'PipelineJobs', type: :request do
  let(:user)         { create(:user) }
  let(:pipeline)     { create(:pipeline) }
  let(:destination)  { create(:destination) }
  let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }

  before do
    sign_in(user)
  end

  describe 'GET /index' do
    it 'displays a list of pipeline jobs' do
      get pipeline_pipeline_jobs_path(pipeline)

      expect(response.status).to eq 200
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new PipelineJob' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id
            }
          }
        end.to change(PipelineJob, :count).by(1)
      end
  
      it 'queues a PipelineWorker' do
        expect(PipelineWorker).to receive(:perform_async)
  
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }
      end
  
      it 'redirects to the Pipeline Jobs table' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }
  
        expect(response).to redirect_to(pipeline_pipeline_jobs_path(pipeline))
      end

      it 'displays an appropriate message' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          }
        }

        follow_redirect!
        expect(response.body).to include 'Pipeline job created successfully'
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new PipelineJob' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: nil
            }
          }
        end.to change(PipelineJob, :count).by(0)
      end
      
      it 'does not queue a PipelineWorker' do
        expect(PipelineWorker).not_to receive(:perform_async)
  
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: nil
          }
        }
      end
  
      it 'redirects to the Pipeline Jobs table' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: nil
          }
        }
  
        expect(response).to redirect_to(pipeline_pipeline_jobs_path(pipeline))
      end

      it 'displays an appropriate message' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: nil
          }
        }

        follow_redirect!
        expect(response.body).to include 'There was an issue creating your pipeline job'
      end
    end
  end

  describe 'POST /cancel' do
    let!(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
    let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
    let!(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }

    context 'when the cancellation is successful' do
      it 'cancels the pipeline and harvest extraction_jobs' do
        expect(pipeline_job.cancelled?).to eq false
        expect(harvest_job.cancelled?).to eq false

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to eq true
        expect(harvest_job.cancelled?).to eq true
        expect(harvest_job.extraction_job.cancelled?).to eq true
      end

      it 'displays an appropriate message' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        follow_redirect!
        expect(response.body).to include 'Pipeline job cancelled successfully'
      end

      it 'redirects to the pipeline jobs table' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)
        
        expect(response).to redirect_to pipeline_pipeline_jobs_path(pipeline)
      end
    end

    context 'when the cancellation is not successful' do
      before do
        allow_any_instance_of(PipelineJob).to receive(:cancelled!).and_return(false)
      end

      it 'does not cancel the harvest extraction jobs' do
        expect(pipeline_job.cancelled?).to eq false
        expect(harvest_job.cancelled?).to eq false

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to eq false
        expect(harvest_job.cancelled?).to eq false
        expect(harvest_job.extraction_job.cancelled?).to eq false
      end

      it 'displays an appropriate message' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        follow_redirect!
        expect(response.body).to include 'There was an issue cancelling your pipeline job'
      end

      it 'redirects to the pipeline jobs table' do
        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)
        
        expect(response).to redirect_to pipeline_pipeline_jobs_path(pipeline)
      end
    end
  end
end
