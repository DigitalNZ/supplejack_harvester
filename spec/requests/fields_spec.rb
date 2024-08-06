# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Fields' do
  let(:user)                       { create(:user) }
  let(:pipeline)                   { create(:pipeline, :figshare) }
  let(:extraction_definition)      { pipeline.harvest.extraction_definition }
  let(:harvest_definition)         { create(:harvest_definition, transformation_definition:, pipeline:) }
  let(:extraction_job)             { create(:extraction_job, extraction_definition:) }
  let!(:transformation_definition) do
    create(:transformation_definition, pipeline:, extraction_job:, record_selector: '$..items')
  end

  before do
    sign_in user
  end

  describe '#create' do
    let(:field) { build(:field, transformation_definition:) }

    context 'with valid parameters' do
      it 'creates a new field' do
        expect do
          post pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
            field: field.attributes
          }
        end.to change(Field, :count).by(1)
      end

      it 'updates the transformation definition last_edited_by' do
        post pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
          field: field.attributes
        }

        expect(transformation_definition.reload.last_edited_by).to eq user
      end

      it 'returns a JSON object representing the new field' do
        post pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
          field: field.attributes
        }

        field = response.parsed_body

        expect(field['name']).to eq 'title'
        expect(field['block']).to eq "JsonPath.new('title').on(record).first"
      end
    end
  end

  describe '#update' do
    let(:field) { create(:field, transformation_definition:) }

    context 'with valid parameters' do
      it 'updates the field' do
        patch pipeline_harvest_definition_transformation_definition_field_path(pipeline, harvest_definition, transformation_definition, field), params: {
          field: { name: 'Description' }
        }

        expect(field.reload.name).to eq 'Description'
      end

      it 'updates the transformation definition last_edited_by' do
        patch pipeline_harvest_definition_transformation_definition_field_path(pipeline, harvest_definition, transformation_definition, field), params: {
          field: { name: 'Description' }
        }

        expect(transformation_definition.reload.last_edited_by).to eq user
      end

      it 'returns a JSON hash of the updated field' do
        patch pipeline_harvest_definition_transformation_definition_field_path(pipeline, harvest_definition, transformation_definition, field), params: {
          field: { name: 'Description' }
        }

        expect(response.parsed_body['name']).to eq 'Description'
      end

      context 'with schema fields' do
        let(:schema) { create(:schema) }
        let(:schema_field) { create(:schema_field, schema:, kind: 'fixed') }
        let!(:schema_field_value) { create(:schema_field_value, value: 'test', schema_field:) }
        let!(:schema_field_value_two) { create(:schema_field_value, value: 'testing', schema_field:) }

        it 'adds provided schema field values into the field' do
          patch pipeline_harvest_definition_transformation_definition_field_path(pipeline, harvest_definition, transformation_definition, field), params: {
            field: { name: 'Description', schema_field_id: schema_field.id, schema_field_value_ids: [schema_field_value.id, schema_field_value_two.id] }
          } 
          
          expect(response.parsed_body['block']).to eq 'test testing'
          expect(response.parsed_body['schema_field_values']).to eq [schema_field_value.id, schema_field_value_two.id]
        end
      end
    end
  end

  describe '#destroy' do
    let!(:field) { create(:field, transformation_definition:) }

    it 'deletes the field' do
      expect do
        delete pipeline_harvest_definition_transformation_definition_field_path(pipeline, harvest_definition, transformation_definition,
                                                                                field)
      end.to change(Field, :count).by(-1)
    end

    it 'updates the transformation definition last_edited_by' do
      delete pipeline_harvest_definition_transformation_definition_field_path(
        pipeline, harvest_definition, transformation_definition, field
      )

      expect(transformation_definition.reload.last_edited_by).to eq user
    end

    it 'returns a successful response' do
      delete pipeline_harvest_definition_transformation_definition_field_path(pipeline, harvest_definition,
                                                                              transformation_definition, field)

      expect(response).to have_http_status(:ok)
    end
  end

  describe '#run' do
    context 'with a valid fields' do
      let(:request) { create(:request, :figshare_initial_request, extraction_definition:) }
      let!(:field_one) do
        create(:field, name: 'title', block: "record['title']", transformation_definition:)
      end
      let!(:field_two) do
        create(:field, name: 'dc_identifier', block: "record['article_id']",
                       transformation_definition:)
      end

      before do
        stub_figshare_harvest_requests(request)
        ExtractionWorker.new.perform(extraction_job.id)
      end

      it 'returns a new record made up of the given transformation fields' do
        post run_pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
          fields: [field_one.id, field_two.id],
          page: 1,
          record: 1
        }

        transformed_record = response.parsed_body['transformation']['transformed_record']

        expect(transformed_record['title']).to eq 'Visual outcomes with femtosecond laser-assisted cataract surgery versus conventional cataract surgery in toric IOL insertion'
        expect(transformed_record['dc_identifier']).to eq 22_947_914
      end

      it 'returns a new record with rejection reasons if the record should be rejected' do
        reject_field = create(:field, kind: 'reject_if', name: 'reject_block', block: 'true',
                                      transformation_definition:)

        post run_pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
          fields: [reject_field.id],
          page: 1,
          record: 1
        }

        body = response.parsed_body['transformation']

        expect(body['rejection_reasons']).to include 'reject_block'
      end

      it 'returns a new record with deletion reasons if the record should be deleted' do
        delete_field = create(:field, kind: 'delete_if', name: 'delete_block', block: 'true',
                                      transformation_definition:)

        post run_pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
          fields: [delete_field.id],
          page: 1,
          record: 1
        }

        body = response.parsed_body['transformation']

        expect(body['deletion_reasons']).to include 'delete_block'
      end

      it 'returns a new record with the fields ordered by created at' do
        post run_pipeline_harvest_definition_transformation_definition_fields_path(pipeline, harvest_definition, transformation_definition), params: {
          fields: [field_one.id, field_two.id],
          page: 1,
          record: 1
        }

        transformed_record = JSON.parse(response.body)['transformation']['transformed_record']

        expect(transformed_record.keys.first).to eq 'dc_identifier'
      end
    end
  end
end
