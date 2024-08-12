# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Schemas' do
  let(:user)   { create(:user) }
  let(:schema) { create(:schema) }

  before do
    sign_in user
  end

  describe 'GET /index' do
    it 'displays a list of schemas' do
      get schemas_path

      expect(response).to have_http_status :ok
    end
  end

  describe 'GET /show' do
    it 'displays a particular schema' do
      get schema_path(schema)

      expect(response).to have_http_status :ok
    end

    it 'assigns the schema redux state' do
      get schema_path(schema)

      expected_state = {
        entities: {
          schemaFields: {
            ids: [],
            entities: {}
          },
          schemaFieldValues: {
            ids: [],
            entities: {}
          },
          appDetails: {
            schema: {
              id: schema.id,
              name: schema.name,
              description: schema.description,
              created_at: schema.created_at,
              updated_at: schema.updated_at,
              last_edited_by_id: schema.last_edited_by_id
            }
          }
        },
        ui: {
          schemaFields: {
            ids: [],
            entities: {}
          }
        },
        config: {
          environment: Rails.env
        }
      }.to_json

      expect(assigns(:props)).to eq(expected_state)
    end
  end

  describe 'POST /create' do
    context 'with valid attributes' do
      it 'creates a new schema' do
        expect do
          post schemas_path, params: {
            schema: attributes_for(:schema)
          }
        end.to change(Schema, :count).by(1)
      end

      it 'redirects to the schemas page' do
        post schemas_path, params: {
          schema: attributes_for(:schema)
        }

        expect(response).to redirect_to schemas_path
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new schema' do
        expect do
          post schemas_path, params: {
            schema: { name: '' }
          }
        end.not_to change(Schema, :count)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:schema) { create(:schema) }

    it 'deletes a schema' do
      expect do
        delete schema_path(schema)
      end.to change(Schema, :count).by(-1)
    end

    it 'redirects to the schemas page' do
      delete schema_path(schema)

      expect(response).to redirect_to schemas_path
    end

    it 'does not delete the schema if something goes wrong' do
      allow_any_instance_of(Schema).to receive(:destroy).and_return(false)

      delete schema_path(schema)

      expect(response).to redirect_to schema_path(schema)
    end
  end

  describe 'PATCH /update' do
    context 'with valid attributes' do
      it 'updates an existing schema' do
        patch schema_path(schema), params: {
          schema: { name: 'Updated schema' }
        }

        schema.reload

        expect(schema.name).to eq 'Updated schema'
      end

      it 'redirects to the schema page' do
        patch schema_path(schema), params: {
          schema: { name: 'Updated schema' }
        }

        expect(response).to redirect_to schema_path(schema)
      end
    end

    context 'with invalid attributes' do
      it 'does not update an existing schema' do
        patch schema_path(schema), params: {
          schema: { name: nil }
        }

        schema.reload

        expect(schema.name).not_to be_nil
      end
    end
  end
end