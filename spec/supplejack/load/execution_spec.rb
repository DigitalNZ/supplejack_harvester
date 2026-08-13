# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Load::Execution do
  let(:record) do
    {
      transformed_record: {
        title: 'title',
        description: 'description'
      }
    }
  end

  let(:pipeline)    { create(:pipeline, name: 'test') }
  let(:destination) { create(:destination) }

  describe '#call' do
    context 'when the harvest definition is for a harvest' do
      before do
        stub_request(:post, 'http://www.localhost:3000/harvester/records/create_batch')
          .with(
            body: "{\"records\":[{\"fields\":{\"title\":[\"title\"],\"description\":[\"description\"],\"source_id\":\"test\",\"priority\":0,\"job_id\":\"#{harvest_job.name}\"}}]}",
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authentication-Token' => 'testkey',
              'Content-Type' => 'application/json',
              'User-Agent' => 'Supplejack Harvester v2.0'
            }
          )
          .to_return(status: 200, body: '', headers: {})
      end

      let(:pipeline)           { create(:pipeline) }
      let(:destination)        { create(:destination) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, kind: 'harvest', source_id: 'test') }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }

      it 'sends the record to the API correctly' do
        expect(described_class.new([record], harvest_job).call.status).to eq 200
      end
    end

    context 'when the harvest definition is for an enrichment' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:, kind: 'enrichment', source_id: 'test') }
      let(:pipeline)           { create(:pipeline) }
      let(:destination)        { create(:destination) }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }

      before do
        stub_request(:post, 'http://www.localhost:3000/harvester/records/record_id/fragments')
          .with(
            body: "{\"fragment\":{\"title\":[\"title\"],\"description\":[\"description\"],\"source_id\":\"test\",\"priority\":0,\"job_id\":\"#{harvest_job.name}\"},\"required_fragments\":null}",
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authentication-Token' => 'testkey',
              'Content-Type' => 'application/json',
              'User-Agent' => 'Supplejack Harvester v2.0'
            }
          )
          .to_return(status: 200, body: '', headers: {})
      end

      it 'sends the record to the API correctly' do
        expect(described_class.new([record], harvest_job, 'record_id').call.status).to eq 200
      end
    end

    context 'when the block writes a secondary fragment' do
      let(:load_definition)    { create(:load_definition, pipeline:, kind: 'secondary_fragment', priority: -1) }
      let(:harvest_definition) do
        create(:harvest_definition, pipeline:, kind: 'harvest', source_id: 'test', priority: -1, load_definition:)
      end
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)  { create(:harvest_job, harvest_definition:, pipeline_job:) }

      before do
        stub_request(:post, 'http://www.localhost:3000/harvester/records/create_batch')
          .to_return(status: 200, body: '', headers: {})
      end

      it 'goes through create_batch, which addresses the record by internal_identifier' do
        expect(described_class.new([record], harvest_job).call.status).to eq 200

        expect(a_request(:post, 'http://www.localhost:3000/harvester/records/create_batch')
          .with { |req| JSON.parse(req.body)['records'].first['fields']['priority'] == -1 }).to have_been_made
      end
    end

    context 'when the block writes to disk rather than the API' do
      let(:load_definition)    { create(:load_definition, pipeline:, kind: 'file') }
      let(:harvest_definition) do
        create(:harvest_definition, pipeline:, kind: 'preprocess', source_id: 'test', load_definition:)
      end
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)  { create(:harvest_job, harvest_definition:, pipeline_job:) }

      it 'raises instead of returning nil for handle_response to trip over' do
        expect { described_class.new([record], harvest_job).call }
          .to raise_error(StandardError, 'a file definition cannot be loaded')
      end
    end
  end
end
