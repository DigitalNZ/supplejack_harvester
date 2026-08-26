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

      # Nothing left to configure once the form is submitted, so the user goes back to the
      # pipeline rather than to a page that only repeats what they just filled in.
      it 'goes back to the pipeline' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: valid_params

        expect(response).to redirect_to pipeline_path(pipeline)
      end
    end

    context 'when created under a pre-processing block' do
      let!(:preprocess_definition) do
        create(:harvest_definition, kind: :preprocess, pipeline:, source_id: 'pre-0')
      end

      it 'auto-names the definition after the pre-processing block' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, preprocess_definition), params: {
          load_definition: { pipeline_id: pipeline.id, kind: 'preprocessed_data' }
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

      # The redirect leaves the unsaved definition behind, so the alert is the only place the
      # reason can survive to.
      it 'says why in the alert, not just that it failed' do
        post pipeline_harvest_definition_load_definitions_path(pipeline, harvest_definition), params: {
          load_definition: { pipeline_id: pipeline.id, kind: 'secondary_fragment', priority: 0 }
        }

        expect(flash[:alert]).to include 'There was an issue creating your Load Definition'
        expect(flash[:alert]).to include 'must not be 0'
      end
    end

    # The kind is chosen from a select that only offers what the block can do, so getting here
    # means going around the form. It still must not leave a definition nothing can use.
    context 'when the kind is not something the block can do' do
      let!(:preprocess_definition) do
        create(:harvest_definition, kind: :preprocess, pipeline:, source_id: 'pre-0')
      end

      def post_enrichment_load
        post pipeline_harvest_definition_load_definitions_path(pipeline, preprocess_definition), params: {
          load_definition: { pipeline_id: pipeline.id, kind: 'enrichment', priority: -1 }
        }
      end

      it 'leaves no load definition behind' do
        expect { post_enrichment_load }.not_to change(LoadDefinition, :count)
      end

      it 'leaves the block with the one it had' do
        had = preprocess_definition.load_definition

        post_enrichment_load

        expect(preprocess_definition.reload.load_definition).to eq had
      end

      it 'says what the block objected to' do
        post_enrichment_load

        expect(flash[:alert]).to include 'cannot be a enrichment load on a preprocess block'
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

    it 'names the wait the default stands for, so it need not be guessed at' do
      get pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)

      expect(response.body).to include "Default (#{LoadDefinition.read_timeout_label(
        LoadDefinition.default_read_timeout
      )})"
    end

    it 'does not offer that same wait again further down the list' do
      get pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)

      expect(response.body).not_to include %(<option value="#{LoadDefinition.default_read_timeout}">)
    end

    # Only the settings that mean something for what this block can do - see PipelinesHelper.
    it 'asks a harvest block for a priority but not for a required fragment' do
      get pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)

      expect(response.body).to include 'load_definition[priority]'
      expect(response.body).not_to include 'load_definition[required_for_active_record]'
    end

    # The attribute order Rails emits is not something to depend on, so the whole input is
    # picked out and asked whether it is readonly.
    def priority_input
      response.body[/<input[^>]*name="load_definition\[priority\]"[^>]*>/]
    end

    it 'leaves the priority editable for a secondary fragment' do
      get pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)

      expect(priority_input).not_to include 'readonly'
      expect(priority_input).to include 'form-control"'
    end

    # Readonly and styled as plain text, the number being 0 by definition rather than a choice.
    it 'fixes the priority for the primary fragment, which is always 0' do
      load_definition.update!(kind: 'primary_fragment', priority: 0)

      get pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition)

      expect(priority_input).to include 'readonly'
      expect(priority_input).to include 'form-control-plaintext'
    end

    it 'asks an enrichment for both' do
      enrichment = create(:harvest_definition, pipeline:, kind: :enrichment, source_id: 'an-enrichment',
                                               load_definition: create(:load_definition, pipeline:,
                                                                                         kind: 'enrichment'))

      get pipeline_harvest_definition_load_definition_path(pipeline, enrichment, enrichment.load_definition)

      expect(response.body).to include 'load_definition[priority]'
      expect(response.body).to include 'load_definition[required_for_active_record]'
    end

    it 'asks a pre-processing block for neither, having no fragment to write' do
      preprocess = create(:harvest_definition, pipeline:, kind: :preprocess, source_id: 'a-preprocess',
                                               load_definition: create(:load_definition, pipeline:, kind: 'preprocessed_data'))

      get pipeline_harvest_definition_load_definition_path(pipeline, preprocess, preprocess.load_definition)

      expect(response.body).not_to include 'load_definition[priority]'
      expect(response.body).not_to include 'load_definition[required_for_active_record]'
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

    # Why a load definition could refuse to save with nothing on the form saying so: both of
    # these land on a select, and VerticalFormBuilder only knew how to mark the fields a user
    # types into.
    it 'says why when the refusal is about the response timeout, which is a select' do
      patch pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition, load_definition), params: {
        load_definition: { read_timeout: 45 }
      }

      expect(response.body).to include 'is not included in the list'
    end

    context 'when a block that cannot do this kind is already attached to it' do
      before do
        # The block side refuses this pairing, so it takes update_columns to build the state -
        # but rows predating that validation exist, and then nothing about the definition saves.
        create(:harvest_definition, pipeline:, kind: 'enrichment', source_id: 'enriching')
          .update_columns(load_definition_id: load_definition.id) # rubocop:disable Rails/SkipsModelValidations
      end

      it 'says why, though the kind is a select too' do
        patch pipeline_harvest_definition_load_definition_path(pipeline, harvest_definition,
                                                               load_definition), params: {
                                                                 load_definition: { name: load_definition.name }
                                                               }

        expect(response.body).to include 'is not something the enrichment block enriching can do'
      end
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
