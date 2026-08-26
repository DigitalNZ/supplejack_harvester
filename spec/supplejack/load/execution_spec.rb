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
            body: "{\"fragment\":{\"title\":[\"title\"],\"description\":[\"description\"],\"source_id\":\"test\",\"priority\":-1,\"job_id\":\"#{harvest_job.name}\"},\"required_fragments\":null}",
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

    # Only a 2xx means the batch landed. Anything but an exact 500 used to be counted as a
    # success, so records the destination never took were reported as loaded.
    context 'when the destination refuses the batch' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:, kind: 'harvest', source_id: 'test') }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }

      def stub_status(status)
        stub_request(:post, 'http://www.localhost:3000/harvester/records/create_batch')
          .to_return(status:, body: '', headers: {})
      end

      # A struggling destination behind a proxy answers with 502/503/504, not with a 500, and
      # 408/429 are it asking to be tried again. The exact class matters as much as the
      # message: PermanentError is a StandardError, so matching the parent proves nothing.
      [500, 502, 503, 504, 408, 429].each do |status|
        it "raises a retryable error on #{status}" do
          stub_status(status)

          expect { described_class.new([record], harvest_job).call }
            .to raise_error(an_instance_of(StandardError)
              .and(having_attributes(message: "Destination API responded with status #{status}")))
        end
      end

      # Retrying a batch the destination called malformed or oversized only delays the run.
      [400, 401, 413, 422].each do |status|
        it "raises a permanent error on #{status}" do
          stub_status(status)

          expect { described_class.new([record], harvest_job).call }
            .to raise_error(Load::PermanentError, "Destination API responded with status #{status}")
        end
      end

      it 'treats a redirect as a destination URL that needs fixing rather than retrying' do
        stub_status(302)

        expect { described_class.new([record], harvest_job).call }.to raise_error(Load::PermanentError)
      end
    end

    # The destination writes a batch one record at a time, so a source whose records are large
    # can be given longer without every other destination call in the app waiting with it.
    context 'when the load definition sets a response timeout' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:, kind: 'harvest', source_id: 'test') }
      let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }

      let(:api) { instance_double(Api::Harvester::Record, create_batch: instance_double(Faraday::Response, success?: true)) }

      it 'asks Faraday to wait that long' do
        harvest_definition.load_definition.update!(read_timeout: 180)
        allow(Api::Harvester::Record).to receive(:new).and_return(api)

        described_class.new([record], harvest_job).call

        expect(Api::Harvester::Record).to have_received(:new).with(destination, read_timeout: 180)
      end

      it 'says nothing about the timeout when the definition does not set one' do
        harvest_definition.load_definition.update!(read_timeout: nil)
        allow(Api::Harvester::Record).to receive(:new).and_return(api)

        described_class.new([record], harvest_job).call

        expect(Api::Harvester::Record).to have_received(:new).with(destination, read_timeout: nil)
      end
    end

    context 'when the block writes to disk rather than the API' do
      let(:load_definition)    { create(:load_definition, pipeline:, kind: 'preprocessed_data') }
      let(:harvest_definition) do
        create(:harvest_definition, pipeline:, kind: 'preprocess', source_id: 'test', load_definition:)
      end
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_job)  { create(:harvest_job, harvest_definition:, pipeline_job:) }

      it 'raises instead of returning nil for handle_response to trip over' do
        expect { described_class.new([record], harvest_job).call }
          .to raise_error(Load::PermanentError, 'a preprocessed_data definition cannot be loaded')
      end
    end
  end
end
