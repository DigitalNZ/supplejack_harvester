# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pipelines' do
  let(:user) { create(:user) }
  let!(:pipeline) { create(:pipeline, name: 'DigitalNZ Production') }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }

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

    it 'offers "Add Pre-processing block" in the add-block dropdown before any blocks exist' do
      empty_pipeline = create(:pipeline, name: 'Empty pipeline')

      get pipeline_path(empty_pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Add Pre-processing block'
    end

    it 'still offers "Add Pre-processing block" once the pipeline has blocks' do
      create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'pre-one')

      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Add Pre-processing block'
      # The add-preprocess modal's hidden position must append to the END of the existing
      # preprocess chain (one block at position 0 exists, so the next one goes to 1).
      expect(response.body).to match(/value="1"[^>]*name="harvest_definition\[position\]"/)
    end

    it 'offers "Add Harvest" when the pipeline has blocks but no harvest yet' do
      preprocess_pipeline = create(:pipeline, name: 'Preprocess only')
      create(:harvest_definition, pipeline: preprocess_pipeline, kind: :preprocess, position: 0,
                                  source_id: 'pre-one')

      get pipeline_path(preprocess_pipeline)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Add Harvest'
    end

    it 'does not offer "Add Harvest" when the pipeline already has a harvest' do
      get pipeline_path(pipeline)

      expect(response).to have_http_status :ok
      # "Add Harvest" (capital H) is the dropdown entry's exact label; the harvest block's own
      # "+ Add harvest extraction/transformation" CTAs and the "Add harvest" modal heading are
      # lowercase-h, so this assertion targets only the dropdown entry.
      expect(response.body).not_to include 'Add Harvest'
    end

    it 'renders preprocess blocks in position order, before the harvest' do
      harvest_definition.update!(source_id: 'harvest-block', position: 2)
      create(:harvest_definition, pipeline:, kind: :preprocess, position: 0, source_id: 'pre-one')
      create(:harvest_definition, pipeline:, kind: :preprocess, position: 1, source_id: 'pre-two')

      get pipeline_path(pipeline)

      body = response.body
      expect(body.index('pre-one')).to be < body.index('pre-two')
      expect(body.index('pre-two')).to be < body.index('harvest-block')
    end

    it "points a pre-processing block's create-extraction-definition form at its own " \
       'harvest_definition, not the pipeline harvest' do
      preprocess = create(:harvest_definition, pipeline:, kind: :preprocess, position: 0,
                                               source_id: 'pre-one', extraction_definition: nil)

      get pipeline_path(pipeline)

      expected_action = pipeline_harvest_definition_extraction_definitions_path(pipeline, preprocess)
      wrong_action = pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition)

      # Match the exact quoted form `action="..."` attribute (not a loose substring), since the
      # harvest's own extraction/transformation *member* routes (edit/delete/jobs links, which DO
      # already exist for `harvest_definition` on this page) share the same collection path as a
      # prefix, e.g. ".../extraction_definitions/42" - a plain #include? on the bare path would
      # give a false failure there.
      expect(response.body).to include "action=\"#{CGI.escapeHTML(expected_action)}\""
      expect(response.body).not_to include "action=\"#{CGI.escapeHTML(wrong_action)}\""
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

  describe 'GET /harvest_definitions' do
    it 'returns status 200' do
      get harvest_definitions_pipeline_path(pipeline)
      expect(response).to have_http_status :ok
    end

    it 'renders the harvest definitions for a pipeline as JSON' do
      get harvest_definitions_pipeline_path(pipeline)

      expect(response.body).to eq pipeline.harvest_definitions.map(&:to_h).to_json
    end
  end

  describe '/POST clone' do

    let(:pipeline)                  { create(:pipeline) }

    let(:extraction_definition)     { create(:extraction_definition) }
    let!(:request_one)              { create(:request, :figshare_initial_request, extraction_definition:) }
    let!(:request_two)              { create(:request, :figshare_main_request, extraction_definition:) }

    let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
    let(:request)                   { create(:request, :figshare_initial_request, extraction_definition:) }
    let(:transformation_definition) do
      create(:transformation_definition, pipeline:, extraction_job:, record_selector: '$..items')
    end

    let!(:field_one) do
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition:)
    end
    let!(:field_two) do
      create(:field, name: 'source', block: "JsonPath.new('source').on(record).first", transformation_definition:)
    end

    let!(:harvest_definition)    { create(:harvest_definition, extraction_definition:, transformation_definition:, pipeline:, priority: -1) }
    
    context 'when the clone is successful' do
      it 'redirects to the new Pipeline page' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: 'copy'
          }
        }
  
        expect(response).to redirect_to pipeline_path(Pipeline.last)
      end
  
      it 'creates a new pipeline' do
        expect do
          post clone_pipeline_path(pipeline), params: {
            pipeline: {
              name: 'copy'
            }
          }
        end.to change(Pipeline, :count).by(1)
      end
  
      it 'creates new harvest definitions based on the provided pipeline' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: 'copy'
          }
        }
  
        cloned_pipeline = Pipeline.last
  
        expect(cloned_pipeline).not_to eq pipeline
  
        expect(cloned_pipeline.harvest_definitions.count).to eq pipeline.harvest_definitions.count
        expect(cloned_pipeline.harvest_definitions.first.extraction_definition).to eq pipeline.harvest_definitions.first.extraction_definition
        expect(cloned_pipeline.harvest_definitions.first.transformation_definition).to eq pipeline.harvest_definitions.first.transformation_definition
  
        expect(cloned_pipeline.harvest_definitions.first.extraction_definition.shared?).to eq true
        expect(cloned_pipeline.harvest_definitions.first.transformation_definition.shared?).to eq true
      end
  
      it 'displays a successful message' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: 'copy'
          }
        }
  
        follow_redirect!
  
        expect(response.body).to include 'Pipeline cloned successfully'
      end
    end

    context 'when the clone is not successful' do
      it 'does not create a new pipeline' do
        expect do
          post clone_pipeline_path(pipeline), params: {
            pipeline: {
              name: pipeline.name
            }
          }
        end.to change(Pipeline, :count).by(0)
      end

      it 'displays a helpful message' do
        post clone_pipeline_path(pipeline), params: {
          pipeline: {
            name: pipeline.name
          }
        }

        follow_redirect!

        expect(response.body).to include 'Pipeline clone failed. Please confirm that your Pipeline name is unique and then try again.'
      end
    end
  end
end
