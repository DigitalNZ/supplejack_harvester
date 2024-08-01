require 'rails_helper'

RSpec.describe "SchemaFields", type: :request do
  let(:user) { create(:user) }
  let(:schema) { create(:schema) }

  before do
    sign_in user
  end

  describe 'POST /create' do
    let(:schema_field) { build(:schema_field, schema:) }

    context 'with valid attributes' do
      it 'creates a new schema field' do
        expect do
          post schema_schema_fields_path(schema), params: {
            schema_field: schema_field.attributes
          }
        end.to change(SchemaField, :count).by(1)
      end

      it 'updates the schemas last edited by' do
        post schema_schema_fields_path(schema), params: {
          schema_field: schema_field.attributes
        } 

        expect(schema.reload.last_edited_by).to eq user
      end

      it 'returns a JSON object representing the new field' do
        post schema_schema_fields_path(schema), params: {
          schema_field: schema_field.attributes
        }

        schema_field = response.parsed_body

        expect(schema_field['name']).to eq 'title'
      end
    end
  end

  describe 'PATCH /update' do
    let(:schema_field) { create(:schema_field, schema:) }

    context 'with valid parameters' do
      it 'updates the field' do
        patch schema_schema_field_path(schema, schema_field), params: { schema_field: { name: 'internal_identifier' } }

        expect(schema_field.reload.name).to eq 'internal_identifier'
      end

      it 'updates the schemas last edited by' do
        patch schema_schema_field_path(schema, schema_field), params: { schema_field: { name: 'internal_identifier' } }

        expect(schema.reload.last_edited_by).to eq user
      end

      it 'returns a JSON hash of the updated field' do
        patch schema_schema_field_path(schema, schema_field), params: { schema_field: { name: 'internal_identifier' } }

        expect(response.parsed_body['name']).to eq 'internal_identifier'
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:schema_field) { create(:schema_field, schema:) }

    it 'deletes the schema field' do
      expect do
        delete schema_schema_field_path(schema, schema_field)
      end.to change(SchemaField, :count).by(-1)
    end

    it 'updates the schema last_edited_by' do
      delete schema_schema_field_path(schema, schema_field)

      expect(schema.reload.last_edited_by).to eq user
    end

    it 'returns a successful response' do
      delete schema_schema_field_path(schema, schema_field)

      expect(response).to have_http_status(:ok)
    end
  end
end
