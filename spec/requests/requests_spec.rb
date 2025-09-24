# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Requests' do
  let(:user)                       { create(:user) }
  let(:pipeline)                   { create(:pipeline) }
  let(:harvest_definition)         { create(:harvest_definition, extraction_definition:, pipeline:) }
  let!(:extraction_definition)     { create(:extraction_definition, pipeline:) }

  before do
    sign_in user
  end

  describe 'PATCH /update' do
    let(:request) { create(:request, extraction_definition:) }

    context 'with valid parameters' do
      it 'updates the request' do
        patch pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition, extraction_definition, request), params: {
          request: { http_method: 'POST' }
        }

        expect(request.reload.http_method).to eq 'POST'
      end

      it 'updates the extraction definition last edited by' do
        patch pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition, extraction_definition, request), params: {
          request: { http_method: 'POST' }
        }

        expect(request.reload.extraction_definition.last_edited_by).to eq user
      end

      it 'renders the request as JSON' do
        patch pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition, extraction_definition, request), params: {
          request: { http_method: 'POST' }
        }

        request = response.parsed_body

        expect(request['http_method']).to eq 'POST'
      end
    end
  end

  describe 'GET /show' do    
    context 'when the extraction definition is for a harvest' do
      before do
        stub_figshare_harvest_requests(request_one)
      end
  
      let(:request_one) { create(:request, :figshare_initial_request, extraction_definition:) }
      let(:request_two) { create(:request, :figshare_main_request, extraction_definition:) }

      it 'returns a JSON response of the completed request' do
        get pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition,
                                                                           extraction_definition, request_one)
  
        expect(response).to have_http_status :ok
  
        json_data = response.parsed_body
  
        expected_keys = %w[url format preview http_method created_at updated_at id]
  
        expected_keys.each do |key|
          expect(json_data).to have_key(key)
        end
      end
  
      it 'returns a JSON response of the completed request referencing a response' do
        get pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition,
                                                                           extraction_definition, request_two, previous_request_id: request_one.id)
  
        expect(response).to have_http_status :ok
  
        json_data = response.parsed_body
  
        expected_keys = %w[url format preview http_method created_at updated_at id]
  
        expected_keys.each do |key|
          expect(json_data).to have_key(key)
        end
  
        expect(JSON.parse(json_data['preview']['body'])['page_nr']).to eq 2
      end
    end

    context 'when the extraction definition is for an enrichment' do
      let(:destination) { create(:destination) }
      let(:extraction_definition) { create(:extraction_definition, :enrichment, pipeline:, destination:) }

      let!(:request_one) { create(:request, extraction_definition:) }
      let!(:request_two) { create(:request, extraction_definition:) }

      let!(:parameter)   { create(:parameter, content: "response.body['dc_identifier'].first", kind: 'slug', request: request_two, content_type: 'dynamic') }

      before do
        stub_figshare_enrichment_page1(destination)
      end

      it 'returns a JSON response of data from the API' do
        get pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition,
                                                                           extraction_definition, request_one)

        expect(response).to have_http_status :ok

        json_data = response.parsed_body

        expected_keys = %w[url format preview http_method created_at updated_at id]

        expected_keys.each do |key|
          expect(json_data).to have_key(key)
        end

        expected_preview_keys = %w[page total_pages total_records body]

        preview_data = json_data['preview']

        expected_preview_keys.each do |key|
          expect(preview_data).to have_key(key)
        end
      end

      it 'returns a JSON response of the data from the content partner based on the data from the API' do
        get pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition,
                                                                           extraction_definition, request_two)

        expect(response).to have_http_status :ok

        json_data = response.parsed_body

        expected_keys = %w[http_method base_url url format preview]

        expected_keys.each do |key|
          expect(json_data).to have_key(key)
        end

        content_source_response = JSON.parse(json_data['preview']['body'])

        expect(content_source_response).to have_key('count')
        expect(content_source_response).to have_key('items')
      end
    end
  end
end
