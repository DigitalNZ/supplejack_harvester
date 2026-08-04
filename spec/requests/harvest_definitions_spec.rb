# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HarvestDefinitions' do
  let(:user)                      { create(:user) }
  let!(:pipeline)                 { create(:pipeline, :figshare) }
  let(:extraction_definition)     { pipeline.harvest.extraction_definition }
  let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition) { create(:transformation_definition, extraction_job:) }
  let(:destination)               { create(:destination) }
  let!(:harvest_definition)        { create(:harvest_definition, pipeline:) }

  before do
    sign_in user
  end

  describe 'POST /create' do
    context 'with valid attributes' do
      it 'creates a new harvest definition' do
        expect do
          post pipeline_harvest_definitions_path(pipeline), params: {
            harvest_definition: {
              name: 'Staging',
              pipeline_id: pipeline.id,
              extraction_definition_id: extraction_definition.id,
              transformation_definition_id: transformation_definition.id,
              source_id: 'test'
            }
          }
        end.to change(HarvestDefinition, :count).by(1)
      end

      it 'updates the pipeline last_edited_by' do
        post pipeline_harvest_definitions_path(pipeline), params: {
          harvest_definition: {
            name: 'Staging',
            pipeline_id: pipeline.id,
            extraction_definition_id: extraction_definition.id,
            transformation_definition_id: transformation_definition.id,
            source_id: 'test'
          }
        }

        expect(pipeline.reload.last_edited_by).to eq user
      end

      it 'redirects to the pipeline path' do
        post pipeline_harvest_definitions_path(pipeline), params: {
          harvest_definition: {
            name: 'Staging',
            pipeline_id: pipeline.id,
            extraction_definition_id: extraction_definition.id,
            transformation_definition_id: transformation_definition.id,
            source_id: 'test'
          }
        }

        expect(response).to redirect_to pipeline_path(pipeline)
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new harvest definition' do
        expect do
          post pipeline_harvest_definitions_path(pipeline), params: {
            harvest_definition: { name: nil }
          }
        end.not_to change(HarvestDefinition, :count)
      end
    end

    context 'with preprocess kind and position' do
      it 'creates a preprocess block with a position' do
        post pipeline_harvest_definitions_path(pipeline), params: {
          harvest_definition: { pipeline_id: pipeline.id, source_id: 'tpk_pre_0', kind: 'preprocess', position: 3 }
        }
        definition = pipeline.harvest_definitions.order(:created_at).last
        expect(definition.preprocess?).to be true
        expect(definition.position).to eq(3)
      end
    end

    context 'when a preprocess block is added after the harvest already exists' do
      # A dedicated pipeline/harvest here (rather than the file's shared `pipeline`/
      # `harvest_definition`, which - via the :figshare trait plus its own let! - already
      # carries TWO harvest-kind blocks) so `pipeline.harvest` unambiguously resolves to
      # the one harvest under test.
      #
      # That harvest sits at the schema default position (0). Pipeline#ordered_blocks sorts
      # by (position, id), so without the HarvestDefinitionsController#keep_harvest_last_in_chain
      # guard, a new preprocess block (also created at position 0, appended via the "Add
      # Pre-processing block" modal's `position: pipeline.preprocesses.count`) would tie with
      # the harvest's position and lose the tiebreak (the harvest's id is lower - it was
      # created first), putting the harvest BEFORE the preprocess block it should follow.
      let(:chain_pipeline) { create(:pipeline) }
      let!(:chain_harvest) { create(:harvest_definition, pipeline: chain_pipeline, source_id: 'test') }

      it "bumps the harvest's position so it stays the last chain block" do
        post pipeline_harvest_definitions_path(chain_pipeline), params: {
          harvest_definition: {
            pipeline_id: chain_pipeline.id, source_id: 'tpk_pre_0', kind: 'preprocess', position: 0
          }
        }

        expect(chain_harvest.reload.position).to eq(1)
        expect(chain_pipeline.ordered_blocks.map(&:kind)).to eq(%w[preprocess harvest])
      end

      it 'keeps the harvest last as more preprocess blocks are appended' do
        post pipeline_harvest_definitions_path(chain_pipeline), params: {
          harvest_definition: {
            pipeline_id: chain_pipeline.id, source_id: 'tpk_pre_0', kind: 'preprocess', position: 0
          }
        }
        post pipeline_harvest_definitions_path(chain_pipeline), params: {
          harvest_definition: {
            pipeline_id: chain_pipeline.id, source_id: 'tpk_pre_1', kind: 'preprocess', position: 1
          }
        }

        expect(chain_harvest.reload.position).to eq(2)
        expect(chain_pipeline.ordered_blocks.map(&:source_id)).to eq(%w[tpk_pre_0 tpk_pre_1 test])
      end

      it 'does not move the harvest when it already trails every preprocess block' do
        chain_harvest.update!(position: 5)

        post pipeline_harvest_definitions_path(chain_pipeline), params: {
          harvest_definition: {
            pipeline_id: chain_pipeline.id, source_id: 'tpk_pre_0', kind: 'preprocess', position: 0
          }
        }

        expect(chain_harvest.reload.position).to eq(5)
      end
    end

    context 'when a harvest is added after preprocess blocks already exist' do
      # The Task 10 / full self-serve build sequence: preprocess blocks first (positions 0, 1),
      # THEN the harvest. The #add-harvest modal has no position field, so the harvest would
      # land at the schema default (0) and Pipeline#ordered_blocks' (position, id) sort would
      # place it BETWEEN the preprocess blocks - violating the terminal-harvest invariant the
      # chain stepper depends on. The controller must place a late-added harvest at the end.
      let(:chain_pipeline) { create(:pipeline) }
      let!(:pre_zero) do
        create(:harvest_definition, pipeline: chain_pipeline, kind: :preprocess, position: 0,
                                    source_id: 'tpk_pre_0')
      end
      let!(:pre_one) do
        create(:harvest_definition, pipeline: chain_pipeline, kind: :preprocess, position: 1,
                                    source_id: 'tpk_pre_1')
      end

      it 'places the harvest after the existing preprocess blocks' do
        post pipeline_harvest_definitions_path(chain_pipeline), params: {
          harvest_definition: { pipeline_id: chain_pipeline.id, source_id: 'tpk_harvest', kind: 'harvest' }
        }

        expect(chain_pipeline.harvest.position).to eq(2)
        expect(chain_pipeline.ordered_blocks.map(&:source_id)).to eq(%w[tpk_pre_0 tpk_pre_1 tpk_harvest])
      end
    end
  end

  describe 'PATCH /update' do
    let(:harvest_definition) do
      create(:harvest_definition, name: 'Staging', pipeline:, extraction_definition:, transformation_definition:)
    end

    context 'with valid params' do
      let!(:updated_extraction_definition)     { create(:extraction_definition, base_url: 'http://test.com') }
      let(:updated_field)                      { build(:field, block: 'hello!') }
      let!(:updated_transformation_definition) do
        create(:transformation_definition, pipeline:, extraction_job:, fields: [updated_field])
      end

      it 'updates the harvest definition' do
        patch pipeline_harvest_definition_path(pipeline, harvest_definition), params: {
          harvest_definition: {
            source_id: 'testing'
          }
        }

        harvest_definition.reload

        expect(harvest_definition.source_id).to eq 'testing'
      end

      it 'updates the pipeline last_edited_by' do
        patch pipeline_harvest_definition_path(pipeline, harvest_definition), params: {
          harvest_definition: {
            source_id: 'testing'
          }
        }

        expect(pipeline.reload.last_edited_by).to eq user
      end

      it 'redirects to the pipeline path' do
        patch pipeline_harvest_definition_path(pipeline, harvest_definition), params: {
          harvest_definition: {
            name: 'Production'
          }
        }

        expect(response).to redirect_to pipeline_path(pipeline)
      end
    end

    context 'with invalid params' do
      it 'does not update the harvest definition' do
        patch pipeline_harvest_definition_path(pipeline, harvest_definition), params: {
          harvest_definition: {
            source_id: nil
          }
        }

        harvest_definition.reload

        expect(harvest_definition.source_id).not_to be_nil
      end
    end
  end

  describe 'DELETE /destroy' do
    context 'when the deletion is successful' do
      it 'deletes the Harvest Definition' do
        expect do
         delete pipeline_harvest_definition_path(pipeline, harvest_definition) 
        end.to change(HarvestDefinition, :count).by(-1)
      end

      it 'redirects to the Pipeline path' do
        delete pipeline_harvest_definition_path(pipeline, harvest_definition)

        expect(response).to redirect_to pipeline_path(pipeline)
      end

      it 'displays an appropriate message' do
        delete pipeline_harvest_definition_path(pipeline, harvest_definition)

        follow_redirect!
        
        expect(response.body).to include 'Harvest deleted successfully'
      end
    end

    context 'when the deletion is not successful' do
      before do
        allow_any_instance_of(HarvestDefinition).to receive(:destroy).and_return(false)
      end

      it 'does not delete the Harvest Definition' do
        expect do
          delete pipeline_harvest_definition_path(pipeline, harvest_definition) 
         end.to change(HarvestDefinition, :count).by(0) 
      end

      it 'redirects to the Pipeline path' do
        delete pipeline_harvest_definition_path(pipeline, harvest_definition)

        expect(response).to redirect_to pipeline_path(pipeline)
      end

      it 'displays an appropriate message' do
        delete pipeline_harvest_definition_path(pipeline, harvest_definition)

        follow_redirect!
        
        expect(response.body).to include 'There was an issue deleting your Harvest'
      end
    end
  end
end
