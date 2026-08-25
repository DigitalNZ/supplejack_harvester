# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::Request do
  describe '#get' do
    it 'returns a document' do
      stub_request(:get, 'http://google.com/hello').and_return(fake_response('test'))
      expect(described_class.new(url: 'http://google.com/hello').get).to be_a Extraction::Document
    end

    it 'has a well formed document' do
      init_params = {
        url: 'http://google.com/?url_param=url_value',
        params: { param_param: :param_value },
        headers: { 'Authentication-Token' => 'my-auth-token' }
      }

      stub_request(:get, init_params[:url]).with(
        query: init_params[:params],
        headers: init_params[:headers]
      ).and_return(fake_response('test'))

      doc = described_class.new(**init_params).get

      expect(doc.url.to_s).to eq 'http://google.com/?param_param=param_value&url_param=url_value'
      expect(doc.method).to eq 'GET'
      expect(doc.params).to eq({ 'url_param' => 'url_value', 'param_param' => :param_value })
      expect(doc.request_headers).to eq init_params[:headers].merge('User-Agent' => ENV.fetch('SJ_USER_AGENT', nil))
      expect(doc.status).to eq 200
      expect(doc.response_headers).to eq({})
      expect(doc.body).to eq('{"totalObjects": 200}')
    end
  end

  describe '#put' do
    it 'returns a document naming the method it was sent with' do
      stub_request(:put, 'http://google.com/records/2')
        .with(body: '{"record":{"status":"deleted"}}')
        .and_return(fake_response('test'))

      doc = described_class.new(
        url: 'http://google.com/records/2',
        params: { record: { status: 'deleted' } },
        method: 'put'
      ).put

      expect(doc).to be_a Extraction::Document
      expect(doc.method).to eq 'PUT'
      expect(doc.url.to_s).to eq 'http://google.com/records/2'
    end
  end

  describe '#patch' do
    it 'returns a document naming the method it was sent with' do
      stub_request(:patch, 'http://google.com/records/2')
        .with(body: '{"status":"deleted"}')
        .and_return(fake_response('test'))

      doc = described_class.new(
        url: 'http://google.com/records/2',
        params: { status: 'deleted' },
        method: 'patch'
      ).patch

      expect(doc.method).to eq 'PATCH'
    end
  end

  describe '#delete' do
    it 'returns a document naming the method it was sent with' do
      stub_request(:delete, 'http://google.com/records/2').and_return(fake_response('test'))

      doc = described_class.new(url: 'http://google.com/records/2', method: 'delete').delete

      expect(doc.method).to eq 'DELETE'
    end
  end
end
