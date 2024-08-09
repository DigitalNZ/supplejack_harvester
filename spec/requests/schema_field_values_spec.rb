require 'rails_helper'

RSpec.describe "SchemaFieldValues", type: :request do
  let(:user) { create(:user) }
  let(:schema) { create(:schema) }
  let(:schema_field) { create(:schema_field, schema:) }

  before do
    sign_in user
  end

  describe 'POST /create' do
    let(:schema_field_value) { build(:schema_field_value, schema_field:) }

    context 'with valid attributes' do
      it 'creates a new schema field value' do
        expect do
          post schema_schema_field_schema_field_values_path(schema, schema_field), params: {
            schema_field_value: schema_field_value.attributes
          }
        end.to change(SchemaFieldValue, :count).by(1)
      end

      it 'updates the schemas last edited by' do
        post schema_schema_field_schema_field_values_path(schema, schema_field), params: {
          schema_field_value: schema_field_value.attributes
        }

        expect(schema.reload.last_edited_by).to eq user
      end

      it 'returns a JSON object representing the new field' do
        post schema_schema_field_schema_field_values_path(schema, schema_field), params: {
          schema_field_value: schema_field_value.attributes
        }

        schema_field_value = response.parsed_body

        expect(schema_field_value['value']).to eq 'National Library of New Zealand'
      end
    end
  end

  describe 'PATCH /update' do
    let(:schema_field_value) { create(:schema_field_value, schema_field:) }

    context 'with valid parameters' do
      it 'updates the schema field value' do
        patch schema_schema_field_schema_field_value_path(schema, schema_field, schema_field_value), params: { schema_field_value: { value: 'DigitalNZ' } }

        expect(schema_field_value.reload.value).to eq 'DigitalNZ'
      end

      it 'updates the last edited by' do
        patch schema_schema_field_schema_field_value_path(schema, schema_field, schema_field_value), params: { schema_field_value: { value: 'DigitalNZ' } }

        expect(schema.reload.last_edited_by).to eq user
      end

      it 'returns a JSON hash of the updated field' do
        patch schema_schema_field_schema_field_value_path(schema, schema_field, schema_field_value), params: { schema_field_value: { value: 'DigitalNZ' } } 

        expect(response.parsed_body['value']).to eq 'DigitalNZ'
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:schema_field_value) { create(:schema_field_value, schema_field:) }

    it 'deletes the schema field' do
      expect do
        delete schema_schema_field_schema_field_value_path(schema, schema_field, schema_field_value)
      end.to change(SchemaFieldValue, :count).by(-1)
    end

    it 'updates the schema last_edited_by' do
      delete schema_schema_field_schema_field_value_path(schema, schema_field, schema_field_value)

      expect(schema.reload.last_edited_by).to eq user
    end

    it 'returns a successful response' do
      delete schema_schema_field_schema_field_value_path(schema, schema_field, schema_field_value)

      expect(response).to have_http_status(:ok)
    end
  end
end