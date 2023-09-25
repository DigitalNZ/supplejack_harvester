# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Delete::Execution do
  let(:record) do
    {
      'transformed_record' => {
        'internal_identifier' => 'abc'
      }
    }
  end

  let(:pipeline)           { create(:pipeline, name: 'test') }
  let(:destination)        { create(:destination) }
  let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:, kind: 'harvest') }
  let(:harvest_job)        { create(:harvest_job, harvest_definition:, pipeline_job:) }

  before do
    stub_request(:put, 'http://www.localhost:3000/harvester/records/delete')
      .with(
        body: '{"id":"abc"}',
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

  describe '#call' do
    it 'sends the internal identifier to the API to be deleted' do
      expect(described_class.new(record, destination).call.status).to eq 200
    end
  end
end
