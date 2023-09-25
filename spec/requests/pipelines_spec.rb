# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pipelines' do
  let(:user) { create(:user) }
  let!(:pipeline) { create(:pipeline, name: 'DigitalNZ Production') }

  before do
    sign_in(user)
  end

  describe 'GET /index' do
    it 'displays a list of pipelines' do
      get pipelines_path

      expect(response).to have_http_status :ok
      expect(response.body).to include CGI.escapeHTML(pipeline.name)
    end
  end

  describe 'POST /create' do
    context 'with valid attributes' do
      it 'creates a new pipeline' do
        expect do
          post pipelines_path, params: {
            pipeline: attributes_for(:pipeline)
          }
        end.to change(Pipeline, :count).by(1)
      end

      it 'stores the user who created it' do
        post pipelines_path, params: {
          pipeline: attributes_for(:pipeline)
        }

        expect(Pipeline.last.last_edited_by).to eq user
      end

      it 'redirects to the created pipeline' do
        post pipelines_path, params: {
          pipeline: attributes_for(:pipeline)
        }

        expect(request).to redirect_to(pipeline_path(Pipeline.last))
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new pipeline' do
        expect do
          post pipelines_path, params: {
            pipeline: {
              name: nil,
              description: nil
            }
          }
        end.not_to change(Pipeline, :count)
      end

      it 'renders the :index template' do
        post pipelines_path, params: {
          pipeline: {
            name: nil,
            description: nil
          }
        }

        expect(response.body).to include 'Pipelines'
        expect(response.body).to include 'There was an issue creating your Pipeline'
      end
    end
  end

  describe 'GET /show' do
    it 'renders a specific pipeline' do
      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include pipeline.name
    end
  end

  describe 'GET /edit' do
    it 'renders the edit page successfully' do
      get edit_pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include pipeline.name
    end
  end

  describe 'PATCH /update' do
    context 'with valid parameters' do
      it 'updates the content source' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: 'National Library of New Zealand' }
        }

        pipeline.reload

        expect(pipeline.name).to eq 'National Library of New Zealand'
      end

      it 'stores the user who updated it' do
        sign_out(user)
        new_user = create(:user)
        sign_in(new_user)
        patch pipeline_path(pipeline), params: {
          pipeline: { name: 'National Library of New Zealand' }
        }

        expect(pipeline.reload.last_edited_by).to eq new_user
      end

      it 'redirects to the pipeline page' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: 'National Library of New Zealand' }
        }

        expect(response).to redirect_to pipeline_path(pipeline)
      end
    end

    context 'with invalid paramaters' do
      it 'does not update the pipeline' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: nil }
        }

        pipeline.reload

        expect(pipeline.name).not_to be_nil
      end

      it 're renders the form' do
        patch pipeline_path(pipeline), params: {
          pipeline: { name: nil }
        }

        expect(response.body).to include pipeline.name_in_database
      end
    end
  end

  describe 'DELETE /destroy' do
    context 'when a pipeline is deleted successfully' do
      it 'deletes a pipeline' do
        expect do
          delete pipeline_path(pipeline)
        end.to change(Pipeline, :count).by(-1)
      end

      it 'redirects to the pipelines path' do
        delete pipeline_path(pipeline)

        expect(response).to redirect_to pipelines_path

        follow_redirect!
        expect(response.body).to include 'Pipeline deleted successfully'
      end
    end

    context 'when a pipeline fails to be deleted' do
      before do
        allow_any_instance_of(Pipeline).to receive(:destroy).and_return(false)
      end

      it 'does not delete a pipeline' do
        expect do
          delete pipeline_path(pipeline)
        end.not_to change(Pipeline, :count)
      end

      it 'redirects to the pipeline path and displays a message' do
        delete pipeline_path(pipeline)

        expect(response).to redirect_to(pipeline_path(pipeline))
        follow_redirect!
        expect(response.body).to include 'There was an issue deleting your Pipeline'
      end
    end
  end
end
