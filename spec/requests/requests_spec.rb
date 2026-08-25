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

    context 'with one of the verbs that mutate the content source' do
      it 'updates the request' do
        patch pipeline_harvest_definition_extraction_definition_request_path(pipeline, harvest_definition, extraction_definition, request), params: {
          request: { http_method: 'PUT' }
        }

        expect(request.reload.http_method).to eq 'PUT'
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

      let!(:parameter)   { create(:parameter, content: "response['dc_identifier'].first", kind: 'slug', request: request_two, content_type: 'dynamic') }

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

    context 'when the extraction definition consumes pre-processed data' do
      let!(:preceding_block) do
        create(:harvest_definition, kind: 'preprocess', position: 0, pipeline:)
      end
      let(:extraction_definition) do
        create(:extraction_definition, pipeline:, base_url: 'http://example.com/api')
      end
      let(:harvest_definition) do
        create(:harvest_definition, kind: 'harvest', position: 1, extraction_definition:, pipeline:)
      end
      let!(:request_one) { create(:request, extraction_definition:) }
      let(:pipeline_job)  { create(:pipeline_job, pipeline:) }

      def write_output(job, records)
        PreProcess::Output.new(job.id, 0).write_page(1, records)
      end

      before do
        stub_request(:get, 'http://example.com/api')
          .to_return(status: 200, body: { hello: 'world' }.to_json, headers: fake_json_headers)
      end

      after { FileUtils.rm_rf(Dir.glob("#{PreProcess::Output::FOLDER}/*")) }

      it 'previews the extraction using a pre-processed input record and the URL response' do
        write_output(pipeline_job, [{ 'id' => '123', 'title' => 'Record A' }])

        get pipeline_harvest_definition_extraction_definition_request_path(
          pipeline, harvest_definition, extraction_definition, request_one
        )

        expect(response).to have_http_status :ok
        preview = response.parsed_body['preview']

        expect(preview['total_records']).to eq 1
        expect(preview['current_run_id']).to eq pipeline_job.id
        expect(JSON.parse(preview['input']['body'])).to include('id' => '123', 'title' => 'Record A')
        expect(JSON.parse(preview['response']['body'])).to eq('hello' => 'world')
      end

      it 'lists available runs most-recent-first and defaults to the latest' do
        older = create(:pipeline_job, pipeline:, created_at: 2.days.ago)
        write_output(older, [{ 'id' => 'old' }])
        write_output(pipeline_job, [{ 'id' => 'new' }])

        get pipeline_harvest_definition_extraction_definition_request_path(
          pipeline, harvest_definition, extraction_definition, request_one
        )

        preview = response.parsed_body['preview']
        expect(preview['runs'].map { |run| run['id'] }).to eq [pipeline_job.id, older.id]
        expect(preview['current_run_id']).to eq pipeline_job.id
      end

      it 'previews the run named by pipeline_job_id' do
        other = create(:pipeline_job, pipeline:)
        write_output(other, [{ 'id' => 'other' }])
        write_output(pipeline_job, [{ 'id' => 'main' }])

        get pipeline_harvest_definition_extraction_definition_request_path(
          pipeline, harvest_definition, extraction_definition, request_one
        ), params: { pipeline_job_id: other.id }

        preview = response.parsed_body['preview']
        expect(preview['current_run_id']).to eq other.id
        expect(JSON.parse(preview['input']['body'])).to include('id' => 'other')
      end

      it 'returns an empty preview when the preceding block has no output' do
        get pipeline_harvest_definition_extraction_definition_request_path(
          pipeline, harvest_definition, extraction_definition, request_one
        )

        preview = response.parsed_body['preview']
        expect(preview['runs']).to eq []
        expect(preview['total_records']).to eq 0
        expect(preview['current_run_id']).to be_nil
      end

      # A dynamic expression left as a static parameter is never evaluated, so its
      # #{...} ends up in the URL and the request layer cannot parse it. The preview has
      # to say so: an empty panel sends you looking anywhere but at the parameter.
      it 'reports the URL it tried and why it failed' do
        create(:parameter, kind: 'slug', content_type: 'static', request: request_one,
                           content: %("\#{response['transformed_record']['slug']}/seasons"))
        write_output(pipeline_job, [{ 'transformed_record' => { 'slug' => 'a-show' } }])

        get pipeline_harvest_definition_extraction_definition_request_path(
          pipeline, harvest_definition, extraction_definition, request_one
        )

        response_preview = response.parsed_body['preview']['response']

        expect(response_preview['url']).to include "\#{response['transformed_record']['slug']}"
        expect(JSON.parse(response_preview['body'])['error']).to include 'bad URI'
      end

      it 'does not error when a page file on disk is corrupt' do
        write_output(pipeline_job, [{ 'id' => '123' }])
        page_path = "#{PreProcess::Output.folder(pipeline_job.id, 0)}/1/preprocess__000000001.json"
        File.write(page_path, 'not json{')

        get pipeline_harvest_definition_extraction_definition_request_path(
          pipeline, harvest_definition, extraction_definition, request_one
        )

        expect(response).to have_http_status :ok
        expect(response.parsed_body['preview']['total_records']).to eq 0
      end
    end
  end
end
