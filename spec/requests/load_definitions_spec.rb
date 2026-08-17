# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Load Definitions' do
  let!(:user)               { create(:user) }
  let!(:pipeline)           { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline:) }

  before do
    sign_in user
  end

  describe '#create' do
    context 'with valid parameters' do
      let(:valid_params) do
        { load_definition: { pipeline_id: pipeline.id, kind: 'secondary_fragment', priority: -1 } }
      end

      it 'creates a new load definition' do
        expect do
          post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: valid_params
        end.to change(LoadDefinition, :count).by(1)
      end

      it 'attaches it to the block it was created under' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: valid_params

        expect(harvest_definition.reload.load_definition).to eq LoadDefinition.last
      end

      it 'stores the user who created it' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: valid_params

        expect(LoadDefinition.last.last_edited_by).to eq user
      end

      it 'redirects to the load definition' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: valid_params

        expect(response).to redirect_to pipeline_harvest_definition_load_definition_path(
          pipeline, harvest_definition, LoadDefinition.last
        )
      end
    end

    context 'when created under a pre-processing block' do
      let!(:preprocess_definition) do
        create(:harvest_definition, kind: :preprocess, pipeline:, source_id: 'pre-0')
      end

      it 'auto-names the definition after the pre-processing block' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, preprocess_definition), params: {
          load_definition: { pipeline_id: pipeline.id, kind: 'file' }
        }

        definition = LoadDefinition.order(:id).last
        expect(definition.name).to eq "#{definition.id}_pre-processing-load"
      end
    end

    context 'with invalid parameters' do
      let!(:existing) { create(:load_definition, pipeline:, name: 'taken') }

      it 'does not create a new load definition' do
        expect do
          post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: {
            load_definition: { pipeline_id: pipeline.id, name: existing.name }
          }
        end.not_to change(LoadDefinition, :count)
      end

      it 'redirects to the pipeline' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: {
          load_definition: { pipeline_id: pipeline.id, name: existing.name }
        }

        expect(response).to redirect_to pipeline_path(pipeline)
      end
    end
  end

  describe '#show' do
    let!(:load_definition) { create(:load_definition, pipeline:, kind: 'secondary_fragment', priority: -1) }

    it 'renders the load definition' do
      get pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)

      expect(response).to have_http_status :ok
      expect(response.body).to include load_definition.name
    end
  end

  describe '#update' do
    let!(:load_definition) { create(:load_definition, pipeline:) }

    it 'updates how the block writes' do
      patch pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition), params: {
        load_definition: { kind: 'secondary_fragment', priority: -1 }
      }

      expect(load_definition.reload).to have_attributes(kind: 'secondary_fragment', priority: -1)
    end

    it 'stores the user who edited it' do
      patch pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition), params: {
        load_definition: { kind: 'secondary_fragment', priority: -3 }
      }

      expect(load_definition.reload.last_edited_by).to eq user
    end

    it 'refuses a secondary fragment at priority 0 and says why' do
      patch pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition), params: {
        load_definition: { kind: 'secondary_fragment', priority: 0 }
      }

      expect(load_definition.reload.kind).to eq 'primary_fragment'
      expect(response.body).to include 'must not be 0'
    end
  end

  describe '#destroy' do
    let!(:load_definition) { create(:load_definition, pipeline:) }

    it 'deletes the load definition' do
      expect do
        delete pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)
      end.to change(LoadDefinition, :count).by(-1)
    end
  end

  describe '#clone' do
    let!(:load_definition) { create(:load_definition, pipeline:, kind: 'secondary_fragment', priority: -1) }

    it 'clones it and points the block at the clone' do
      post clone_pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition),
           params: { load_definition: { name: '[CLONE] a load definition' } }

      clone = LoadDefinition.order(:id).last

      expect(clone).to have_attributes(name: '[CLONE] a load definition', kind: 'secondary_fragment', priority: -1)
      expect(harvest_definition.reload.load_definition).to eq clone
    end
  end
end
