# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HarvestDefinitions' do
  let(:user)                      { create(:user) }
  let!(:pipeline)                 { create(:pipeline, :figshare) }
  let(:extraction_definition)     { pipeline.harvest.extraction_definition }
  let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition) { create(:transformation_definition, extraction_job:) }
  let(:destination)               { create(:destination) }
  let(:harvest_definition)        { create(:harvest_definition) }

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
end
