# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::Utils::NoticeHarvestingToApi do
  let(:destination) { create(:destination) }

  def stub_index_request
    stub_request(:get, 'http://www.localhost:3000/harvester/sources?source%5Bsource_id%5D=davetest')
      .with(
        headers: {
          'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authentication-Token' => 'testkey', 'Content-Type' => 'application/json',
          'User-Agent' => 'Supplejack Harvester v2.0'
        }
      )
      .to_return(status: 200, body: [{ _id: 1 }].to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_put_request
    stub_request(:put, 'http://www.localhost:3000/harvester/sources/1')
      .with(
        body: '{"source":{"harvesting":false}}',
        headers: {
          'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authentication-Token' => 'testkey', 'Content-Type' => 'application/json',
          'User-Agent' => 'Supplejack Harvester v2.0'
        }
      )
      .to_return(status: 200, body: '', headers: {})
  end

  it 'makes a request to get the source _id' do
    index_stub = stub_index_request
    stub_put_request
    described_class.new(destination, 'davetest', false).call

    expect(index_stub).to have_been_requested
  end

  it 'makes a request to put the found source_id to false' do
    stub_index_request
    put_stub = stub_put_request
    described_class.new(destination, 'davetest', false).call

    expect(put_stub).to have_been_requested
  end
end
