# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PipelineJobs' do
  let(:user)         { create(:user) }
  let(:pipeline)     { create(:pipeline) }
  let(:destination)  { create(:destination) }
  let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }

  let!(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:, extraction_status: 'completed', transformation_status: 'running', transformation_workers_queued: 1, transformation_workers_completed: 1, load_status: 'running', load_workers_queued: 1, load_workers_completed: 1, delete_status: 'running', delete_workers_queued: 0, delete_workers_completed: 0) }

  before do
    sign_in(user)
  end

  describe 'GET /index' do
    it 'displays a list of pipeline jobs' do
      get pipeline_pipeline_jobs_path(pipeline)

      expect(response).to have_http_status :ok
    end
  end

  describe 'GET /show' do
    it "links to a pre-processing block's transformed data" do
      preprocess_definition = create(:harvest_definition, :preprocess, pipeline:, position: 0)
      preprocess_job = create(:harvest_job, harvest_definition: preprocess_definition, pipeline_job:)
      create(:harvest_report, pipeline_job:, harvest_job: preprocess_job, kind: 'preprocess')

      get pipeline_pipeline_job_path(pipeline, pipeline_job)

      expect(response.body).to include 'View transformed data'
      expect(response.body).to include pipeline_harvest_definition_preprocess_output_path(
        pipeline, preprocess_definition, pipeline_job
      )
    end

    # Every other kind loads its records to the destination, so there is nothing on
    # disk to link to.
    it 'does not offer transformed data for a harvest block' do
      get pipeline_pipeline_job_path(pipeline, pipeline_job)

      expect(response.body).to include 'View extracted data'
      expect(response.body).not_to include 'View transformed data'
    end
  end

  describe 'GET /harvest_jobs/:harvest_job_id/errors' do
    it 'displays grouped errors for extraction, transformation and load' do
      extraction_summary = create(:job_completion_summary,
                                  job_id: harvest_job.extraction_job_id,
                                  process_type: :extraction,
                                  job_type: 'ExtractionJob')
      transformation_summary = create(:job_completion_summary,
                                      job_id: harvest_job.id,
                                      process_type: :transformation,
                                      job_type: 'TransformationJob')

      create(:job_error, job_completion_summary: extraction_summary, job_id: harvest_job.extraction_job_id,
                         job_type: 'ExtractionJob', origin: 'ExtractionWorker',
                         message: "Extraction failure for #{harvest_job.id}")
      create(:job_error, job_completion_summary: extraction_summary, job_id: harvest_job.extraction_job_id,
                         job_type: 'ExtractionJob', origin: 'LoadWorker',
                         message: "Load failure for #{harvest_job.id}")
      create(:job_error, job_completion_summary: transformation_summary, job_id: harvest_job.id,
                         job_type: 'TransformationJob', process_type: :transformation,
                         origin: 'TransformationWorker',
                         message: "Transformation failure for #{harvest_job.id}")

      get pipeline_pipeline_job_harvest_job_errors_path(pipeline, pipeline_job, harvest_job)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Harvest Job Error Details')
      expect(response.body).to include('Extraction')
      expect(response.body).to include('Transformation')
      expect(response.body).to include('Load')
      expect(response.body).to include("Extraction failure for #{harvest_job.id}")
      expect(response.body).to include("Load failure for #{harvest_job.id}")
      expect(response.body).to include("Transformation failure for #{harvest_job.id}")
      expect(response.body).to include("href=\"#{pipeline_path(pipeline)}\"")
      expect(response.body).to include("href=\"#{pipeline_pipeline_job_path(pipeline, pipeline_job)}\"")
    end
  end

  describe 'POST /create' do
    context 'with per-block run settings' do
      let!(:preprocess) { create(:harvest_definition, :preprocess, pipeline:, position: 0) }
      let!(:harvest)    { create(:harvest_definition, pipeline:, position: 1) }
      let(:extraction_job) { create(:extraction_job, extraction_definition: harvest.extraction_definition) }

      it 'stores what runs and what feeds each block' do
        post pipeline_pipeline_jobs_path(pipeline), params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id,
            block_settings: {
              preprocess.id.to_s => { run: '0', input: 'fresh' },
              harvest.id.to_s => { run: '1', input: "extraction_job:#{extraction_job.id}" }
            }
          }
        }

        job = PipelineJob.last

        expect(job.harvest_definitions_to_run).to eq [harvest.id.to_s]
        expect(job.existing_extraction_job_for(harvest)).to eq extraction_job
      end

      it 'rejects a run whose skipped block leaves the next one with no input' do
        expect do
          post pipeline_pipeline_jobs_path(pipeline), params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id,
              block_settings: {
                preprocess.id.to_s => { run: '0', input: 'fresh' },
                harvest.id.to_s => { run: '1', input: 'fresh' }
              }
            }
          }
        end.not_to change(PipelineJob, :count)

        follow_redirect!
        expect(response.body).to include 'There was an issue creating your pipeline job'
      end
    end

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
        end.not_to change(PipelineJob, :count)
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
        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false
        harvest_job.extraction_job.running!

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to be true
        expect(harvest_job.cancelled?).to be true
        expect(harvest_job.extraction_job.cancelled?).to be true
      end

      it 'does not cancel extraction jobs that have allready completed' do
        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to be true
        expect(harvest_job.cancelled?).to be true
        expect(harvest_job.extraction_job.cancelled?).to be false
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
        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false

        post cancel_pipeline_pipeline_job_path(pipeline, pipeline_job)

        pipeline_job.reload
        harvest_job.reload

        expect(pipeline_job.cancelled?).to be false
        expect(harvest_job.cancelled?).to be false
        expect(harvest_job.extraction_job.cancelled?).to be false
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
