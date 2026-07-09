# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::SjApiEnrichmentIterator do
  let(:destination)           { create(:destination) }
  let(:pipeline)              { create(:pipeline) }
  let(:pipeline_job)          { create(:pipeline_job, pipeline:, destination:, skip_previously_enriched: true) }
  let(:harvest_definition)    { create(:harvest_definition, pipeline:) }
  let(:harvest_job)           { create(:harvest_job, harvest_definition:, pipeline_job:) }
  let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, page: 1) }
  let!(:request)              { create(:request, extraction_definition:) }
  let(:extraction_job)        { create(:extraction_job, extraction_definition:, harvest_job:) }

  describe '#each' do
    context 'when skip previously enriched removes records from the result set as they are enriched' do
      let(:all_record_ids)        { (1..100).map(&:to_s) }
      let(:unenriched_record_ids) { all_record_ids.dup }

      before do
        # The API pages over "records without this enrichment fragment".
        # Records disappear from that result set once their fragment lands,
        # so page N is computed against whatever is unenriched at fetch time.
        stub_request(:get, "#{destination.url}/harvester/records")
          .with(query: hash_including('api_key' => 'testkey'))
          .to_return do |request|
            query = Rack::Utils.parse_nested_query(URI(request.uri.to_s).query)
            page = query.dig('search_options', 'page').to_i
            page_of_records = unenriched_record_ids.each_slice(20).to_a[page - 1] || []
            total_pages = (unenriched_record_ids.length / 20.0).ceil

            {
              status: 200,
              headers: { 'Content-Type' => 'application/json' },
              body: {
                records: page_of_records.map { |id| { 'id' => id } },
                meta: { page:, total_pages: }
              }.to_json
            }
          end
      end

      it 'yields every record from the initial result set exactly once' do
        yielded_record_ids = []

        described_class.new(extraction_job).each do |api_document, _page|
          record_ids = JSON.parse(api_document.body)['records'].map { |record| record['id'] }
          yielded_record_ids.concat(record_ids)

          # Simulate the enrichment fragments landing in the API
          # before the next page is fetched.
          unenriched_record_ids.reject! { |id| record_ids.include?(id) }
        end

        expect(yielded_record_ids).to match_array(all_record_ids)
      end
    end
  end
end
