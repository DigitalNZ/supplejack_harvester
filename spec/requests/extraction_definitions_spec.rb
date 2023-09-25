# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ExtractionDefinitions' do
  let(:user)                   { create(:user) }
  let(:pipeline)               { create(:pipeline) }
  let!(:extraction_definition) { create(:extraction_definition) }
  let!(:harvest_definition)    { create(:harvest_definition, extraction_definition:, pipeline:) }

  before do
    sign_in user
  end

  describe '#new' do
    it 'renders the new form' do
      get new_pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, kind: 'harvest')

      expect(response).to have_http_status :ok
    end
  end

  describe '#create' do
    context 'with valid parameters' do
      let(:extraction_definition2) { build(:extraction_definition, pipeline:) }

      it 'creates a new extraction definition' do
        expect do
          post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
            extraction_definition: extraction_definition2.attributes
          }
        end.to change(ExtractionDefinition, :count).by(1)
      end

      it 'stores the user who created it' do
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes
        }

        expect(ExtractionDefinition.last.last_edited_by).to eq user
      end

      it 'creates 2 requests for the new extraction definition' do
        expect do
          post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
            extraction_definition: extraction_definition2.attributes
          }
        end.to change(Request, :count).by(2)

        expect(ExtractionDefinition.last.requests.count).to eq 2
      end

      it 'redirects to the extraction definition' do
        extraction_definition2 = build(:extraction_definition, pipeline:)
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes
        }

        expect(response).to redirect_to pipeline_harvest_definition_extraction_definition_path(pipeline,
                                                                                               harvest_definition, ExtractionDefinition.last)
      end

      it 'associates an extraction definition with a provided harvest definition' do
        harvest_definition = create(:harvest_definition, pipeline:, extraction_definition: nil)
        expect(harvest_definition.extraction_definition).to be_nil

        extraction_definition2 = build(:extraction_definition, pipeline:)
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes.merge(harvest_definition_id: harvest_definition.id)
        }

        harvest_definition.reload

        expect(harvest_definition.extraction_definition).not_to be_nil
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new extraction definition' do
        extraction_definition2 = build(:extraction_definition, format: nil, pipeline:)
        expect do
          post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
            extraction_definition: extraction_definition2.attributes
          }
        end.not_to change(ExtractionDefinition, :count)
      end

      it 'renders the form again' do
        extraction_definition2 = build(:extraction_definition, format: nil, pipeline:)
        post pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
          extraction_definition: extraction_definition2.attributes
        }

        expect(response).to have_http_status :ok
        expect(response.body).to include 'There was an issue creating your Extraction Definition'
      end
    end
  end

  describe '#update' do
    context 'with valid parameters' do
      it 'updates the extraction definition' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { name: 'Flickr' }
        }

        extraction_definition.reload

        expect(extraction_definition.name).to eq 'Flickr'
      end

      it 'stores the user who updated it' do
        sign_out(user)
        new_user = create(:user)
        sign_in(new_user)
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { name: 'Flickr' }
        }

        expect(extraction_definition.reload.last_edited_by).to eq new_user
      end

      it 'redirects to the extraction page' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { name: 'Flickr' }
        }

        expect(response).to redirect_to(pipeline_harvest_definition_extraction_definition_path(pipeline,
                                                                                               harvest_definition, extraction_definition))
      end
    end

    context 'with invalid paramaters' do
      it 'does not update the content source' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { format: nil }
        }

        extraction_definition.reload

        expect(extraction_definition.format).not_to be_nil
      end

      it 're renders the form' do
        patch pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition), params: {
          extraction_definition: { format: nil }
        }

        expect(response.body).to include extraction_definition.name_in_database
      end
    end
  end

  describe '#test_record_extraction' do
    let(:destination)           { create(:destination) }
    let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:) }

    before do
      stub_figshare_enrichment_page1(destination)
    end

    it 'returns a document extraction of API records' do
      post test_record_extraction_pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
        extraction_definition: extraction_definition.attributes
      }

      expect(response).to have_http_status :ok

      json_response = response.parsed_body['body']
      records = JSON.parse(json_response)['records']

      records.each do |record|
        expect(record).to have_key('dc_identifier')
        expect(record).to have_key('internal_identifier')
      end
    end
  end

  describe '#test_enrichment_extraction' do
    let(:destination) { create(:destination) }
    let(:ed) { create(:extraction_definition, :enrichment, destination:) }

    before do
      stub_figshare_enrichment_page1(destination)
    end

    it 'returns a document extraction of data for an enrichment' do
      post test_enrichment_extraction_pipeline_harvest_definition_extraction_definitions_path(pipeline, harvest_definition), params: {
        extraction_definition: ed.attributes
      }

      expect(response).to have_http_status :ok

      json_response = response.parsed_body['body']
      records = JSON.parse(json_response)['items']

      records.each do |record|
        expect(record).to have_key('article_id')
      end
    end
  end
end
