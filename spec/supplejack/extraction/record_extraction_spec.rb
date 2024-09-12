# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::RecordExtraction do
  let(:destination)           { create(:destination) }
  let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:) }

  let!(:request) { create(:request, extraction_definition:) }


  describe '#extract' do
    context 'when the enrichment is not scheduled after a harvest' do
      before do
        stub_request(:get, "#{destination.url}/harvester/records")
          .with(
            query: {
              'api_key' => 'testkey',
              'search' => {
                'status' => 'active',
                'fragments.source_id' => 'test'
              },
              'search_options' => {
                'page' => 1
              }
            },
            headers: fake_json_headers
          ).to_return(fake_response('test_api_records_1'))
      end

      let(:subject) { described_class.new(request, 1) }

      it 'returns an extracted document from a Supplejack API' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end

    context 'when the extraction definition specifies specific fields and subdocuments' do
      let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, fields: 'id,internal_identifier', include_sub_documents: false) }

      before do
        stub_request(:get, "http://www.localhost:3000/harvester/records?api_key=testkey&fields%5B%5D=id&fields%5B%5D=internal_identifier&record_includes=null&search%5Bfragments.source_id%5D=test&search%5Bstatus%5D=active&search_options%5Bpage%5D=1").
        with(
          headers: {
         'Accept'=>'*/*',
         'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
         'Content-Type'=>'application/json',
         'User-Agent'=>'Supplejack Harvester v2.0'
          }).to_return(fake_response('test_api_records_1'))
      end

      let(:subject) { described_class.new(request, 1) }

      it 'specifies the requested fields in the API request' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end

    context 'when the enrichment is scheduled after a harvest' do
      let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, extraction_definition:) }
      let(:harvest_job)        do
        create(:harvest_job, :completed, harvest_definition:, pipeline_job:, target_job_id: 'harvest-job-1')
      end
      let(:subject) { described_class.new(request, 1, harvest_job) }

      before do
        stub_request(:get, "#{destination.url}/harvester/records")
          .with(
            query: {
              'api_key' => 'testkey',
              'search' => {
                'status' => 'active',
                'fragments.job_id' => 'harvest-job-1'
              },
              'search_options' => {
                'page' => 1
              }
            },
            headers: fake_json_headers
          ).to_return(fake_response('test_api_records_1'))
      end

      it 'returns an extraction document from a particular job from a Supplejack API' do
        expect(subject.extract).to be_a(Extraction::Document)
      end
    end
  end
end
