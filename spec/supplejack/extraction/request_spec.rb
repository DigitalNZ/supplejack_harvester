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
end
