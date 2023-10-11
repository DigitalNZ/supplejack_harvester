# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ExtractionJobs', type: :request do
  subject!                    { create(:extraction_job, extraction_definition:) }

  let(:user)                  { create(:user) }
  let(:pipeline)              { create(:pipeline, :figshare) }
  let(:harvest_definition)    { pipeline.harvest }
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:request)                 { create(:request, :figshare_initial_request, extraction_definition:) }

  before do
    sign_in user
  end

  describe '#show' do
    before do
      # that's to test the display of results
      stub_figshare_harvest_requests(request)
      ExtractionWorker.new.perform(subject.id)
      get pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition,
                                                                                extraction_definition, subject)
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
    context 'when the format is HTML' do
      describe 'is successful' do
        it 'redirects to the extraction definition jobs path' do
          post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition,
                                                                                      kind: 'full')

          expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_extraction_jobs_path(
            pipeline, harvest_definition, extraction_definition
          )
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

        it 'redirects to the extraction definition jobs path' do
          post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition,
                                                                                      extraction_definition)

          expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_extraction_jobs_path(
            pipeline, harvest_definition, extraction_definition
          )
        end

        it 'sets a failure message' do
          post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition,
                                                                                      extraction_definition)
          follow_redirect!
          expect(response.body).to include 'There was an issue launching the job'
        end

        it 'does not queue a job' do
          expect(ExtractionWorker).not_to receive(:perform_async)
          post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition,
                                                                                      extraction_definition)
        end
      end
    end

    context 'when the format is JSON' do
      context 'when the type is pipeline' do
        it 'returns information to redirect to the pipeline path' do
          post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition, kind: 'full', type: 'pipeline', format: 'json')

          body = JSON.parse(response.body)

          expect(body['location']).to eq "/pipelines/#{pipeline.id}"
        end

        it 'queues a job' do
          expect(ExtractionWorker).to receive(:perform_async)

          post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition, kind: 'full', type: 'pipeline', format: 'json')
        end
      end

      context 'when the type is transform' do
        context 'when there is allready a Transformation Definition associated with the harvest_definition' do
          it 'updates the Transformation Definition to reference the new job id' do
            existing_extraction_job = harvest_definition.transformation_definition.extraction_job

            post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition, kind: 'full', type: 'transform', format: 'json')

            harvest_definition.reload
            
            expect(harvest_definition.transformation_definition.extraction_job).not_to eq existing_extraction_job
          end
        end

        context 'when there is no Transformation Definition associated with the harvest definition' do
          it 'creates a new Transformation Definition and assigns it to the Harvest Definition' do
            harvest_definition.transformation_definition.destroy
            harvest_definition.reload

            expect(harvest_definition.transformation_definition).to be_nil

            expect do
              post pipeline_harvest_definition_extraction_definition_extraction_jobs_path(pipeline, harvest_definition, extraction_definition, kind: 'full', type: 'transform', format: 'json')
            end.to change(TransformationDefinition, :count).by(1)

            harvest_definition.reload
            expect(harvest_definition.transformation_definition).not_to be_nil
          end
        end
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
        expect(response).to redirect_to(pipeline_pipeline_jobs_path(pipeline))
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
        delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition,
                                                                                     extraction_definition, subject)

        expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition,
                                                                                                              extraction_definition, subject)
      end

      it 'displays an appropriate flash message' do
        delete pipeline_harvest_definition_extraction_definition_extraction_job_path(pipeline, harvest_definition,
                                                                                     extraction_definition, subject)

        follow_redirect!

        expect(response.body).to include 'There was an issue deleting the results'
      end
    end
  end
end
