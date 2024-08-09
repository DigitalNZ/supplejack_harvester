# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FieldSchemaFieldValues', type: :request do
  let(:user) { create(:user) }

  let(:pipeline) { create(:pipeline, :figshare) }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition) { create(:transformation_definition, pipeline:, extraction_job:) }
  let(:field)        { create(:field, transformation_definition:) }

  let(:schema) { create(:schema) }
  let(:schema_field) { create(:schema_field, schema:) }
  let(:schema_field_value) { create(:schema_field_value, schema_field:) }
  let(:schema_field_value_two) { create(:schema_field_value, schema_field:) }


  before do
    sign_in user
  end

  describe 'POST /create' do
    context 'with valid attributes' do
      it 'creates a new FieldSchemaFieldValue' do
        expect do
          post field_schema_field_values_path, params: {
            field_schema_field_value: {
              field_id: field.id,
              schema_field_value_id: schema_field_value.id
            }
          }
        end.to change(FieldSchemaFieldValue, :count).by(1)
      end

      it 'returns a JSON object representing the new field schema field value' do
        post field_schema_field_values_path, params: {
          field_schema_field_value: {
            field_id: field.id,
            schema_field_value_id: schema_field_value.id
          }
        } 

        expect(response.parsed_body['field_id']).to eq field.id
        expect(response.parsed_body['schema_field_value_id']).to eq schema_field_value.id
      end
    end
  end

  describe 'PATCH /update' do
    let!(:field_schema_field_value) { create(:field_schema_field_value, field_id: field.id, schema_field_value_id: schema_field_value.id) }

    context 'with valid attributes' do
      it 'updates the FieldSchemaFieldValue' do
        patch field_schema_field_value_path(field_schema_field_value), params: {
          field_schema_field_value: { schema_field_value_id: schema_field_value_two.id }
        }

        field.reload

        expect(field.schema_field_values).not_to include(schema_field_value)
        expect(field.schema_field_values).to include(schema_field_value_two)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:field_schema_field_value) { create(:field_schema_field_value, field_id: field.id, schema_field_value_id: schema_field_value.id) }

    it 'deletes the field schema field value' do
      expect do
        delete field_schema_field_value_path(field_schema_field_value)
      end.to change(FieldSchemaFieldValue, :count).by(-1)
    end
  end
end