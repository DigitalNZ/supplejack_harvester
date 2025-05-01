# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::PipelineJobs", type: :request do
  let!(:destination)        { create(:destination) }
  let!(:pipeline) { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let!(:harvest_definition_2) { create(:harvest_definition, pipeline:) }
  let(:admin_user) { create(:user, api_key: 'key', role: :admin) }
  let(:user) { create(:user, api_key: 'key') }

  describe "POST /create" do
    context 'when the user is using an admin api key' do
      context 'When the job is successful' do
        context 'when the job priority is provided' do
          it "creates a pipeline job" do
            expect do
              post api_pipeline_jobs_path, params: {
                pipeline_job: {
                  destination_id: destination.id,
                  pipeline_id: pipeline.id,
                  job_priority: 'high_priority'
                },
              },
              headers: { 
                "Authorization" => "Token token=#{admin_user.api_key}"
              }
            end.to change(PipelineJob, :count).by(1)
          end

          it 'enqueues it into the provided priority queue' do
            expect(PipelineWorker).to receive(:perform_async_with_priority).with('high_priority', anything)

            post api_pipeline_jobs_path, params: {
              pipeline_job: {
                destination_id: destination.id,
                pipeline_id: pipeline.id,
                job_priority: 'high_priority'
              },
            },
            headers: { 
              "Authorization" => "Token token=#{admin_user.api_key}"
            }
          end
        end

        context 'when the job priority is not provided' do
          it "creates a pipeline job" do
            expect do
              post api_pipeline_jobs_path, params: {
                pipeline_job: {
                  destination_id: destination.id,
                  pipeline_id: pipeline.id
                },
              },
              headers: { 
                "Authorization" => "Token token=#{admin_user.api_key}"
              }
            end.to change(PipelineJob, :count).by(1)
          end

          it 'enqueues it into the default priority queue' do
            expect(PipelineWorker).to receive(:perform_async_with_priority).with(nil, anything)

            post api_pipeline_jobs_path, params: {
              pipeline_job: {
                destination_id: destination.id,
                pipeline_id: pipeline.id,
              },
            },
            headers: { 
              "Authorization" => "Token token=#{admin_user.api_key}"
            }
          end 
        end

        it "creates a pipeline job" do
          expect do
            post api_pipeline_jobs_path, params: {
              pipeline_job: {
                destination_id: destination.id,
                pipeline_id: pipeline.id
              },
            },
            headers: { 
              "Authorization" => "Token token=#{admin_user.api_key}"
            }
          end.to change(PipelineJob, :count).by(1)
        end

        it "queues a PipelineWorker" do
          expect(PipelineWorker).to receive(:perform_async)

          post api_pipeline_jobs_path, params: {
            pipeline_job: {
              destination_id: destination.id,   
              pipeline_id: pipeline.id
            },
          },
          headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }
        end
    
        it "returns that the job is successful" do
          post api_pipeline_jobs_path, params: {
            pipeline_job: {
              destination_id: destination.id,
              pipeline_id: pipeline.id
            },
          },
          headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['status']).to eq('success')
        end

        context 'when no harvest_definitions_to_run are provided' do
          it 'runs all harvest definitions that belong to the pipeline' do
            post api_pipeline_jobs_path, params: {
              pipeline_job: {
                destination_id: destination.id,
                harvest_definitions_to_run: [],
                pipeline_id: pipeline.id
              },
            },
            headers: { 
              "Authorization" => "Token token=#{admin_user.api_key}"
            }

            expect(PipelineJob.last.harvest_definitions_to_run).to eq([harvest_definition.id, harvest_definition_2.id].map(&:to_s))
          end
        end

        context 'when harvest_definitions_to_run are provided' do
          it 'runs the specified harvest definitions' do
            post api_pipeline_jobs_path, params: {
              pipeline_job: {
                destination_id: destination.id,
                harvest_definitions_to_run: [harvest_definition.id],
                pipeline_id: pipeline.id
              },
            },
            headers: { 
              "Authorization" => "Token token=#{admin_user.api_key}"
            }

            expect(PipelineJob.last.harvest_definitions_to_run).to eq([harvest_definition.id].map(&:to_s))
          end
        end
      end

      context 'When the job fails' do
        it "does not create a pipeline job" do
          expect do
            post api_pipeline_jobs_path, params: {
              pipeline_job: {
                destination_id: nil,
                pipeline_id: pipeline.id
              },
            },
            headers: { 
              "Authorization" => "Token token=#{admin_user.api_key}"
            }
          end.to change(PipelineJob, :count).by(0)
        end

        it "returns that the job failed" do
          post api_pipeline_jobs_path, params: {
            pipeline_job: {
              destination_id: nil,
              pipeline_id: pipeline.id  
            },
          },
          headers: {
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['status']).to eq('failed')
        end

        it "does not queue a PipelineWorker" do
          expect(PipelineWorker).not_to receive(:perform_async)

          post api_pipeline_jobs_path, params: {
            pipeline_job: {
              destination_id: nil,   
              pipeline_id: pipeline.id
            },
          },
          headers: {
            "Authorization" => "Token token=#{admin_user.api_key}"
          }
        end
      end
    end

    context 'when the user is not using an admin api key' do
      it "returns a 401" do
        post api_pipeline_jobs_path, params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id
          },
        },
        headers: {
          "Authorization" => "Token token=#{user.api_key}"
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is not using an api key' do
      it "returns a 401" do
        post api_pipeline_jobs_path, params: {
          pipeline_job: {
            destination_id: destination.id,
            pipeline_id: pipeline.id  
          },
        },
        headers: {
          "Authorization" => "Token token="
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

