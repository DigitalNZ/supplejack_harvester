# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::Connection do
  describe '#get' do
    before do
      stub_request(:get, 'https://google.com/hello?param=value')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Supplejack Harvester v2.0'
          }
        )
        .to_return(status: 200, body: '', headers: {})

      stub_request(:get, 'https://google.com/hello?my_param=my_value&param=value')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Supplejack Harvester v2.0'
          }
        )
        .to_return(status: 200, body: '', headers: {})
    end

    it 'contains the params from the params parameter' do
      conn = described_class.new(url: 'https://google.com/hello', params: { param: :value })
      conn.get
      expect(conn.url.to_s).to eq 'https://google.com/hello?param=value'
    end

    it 'contains the params from the URL parameter' do
      conn = described_class.new(url: 'https://google.com/hello?param=value')
      conn.get
      expect(conn.url.to_s).to eq 'https://google.com/hello?param=value'
    end

    it 'contains both the params from the URL and the params parameter' do
      conn = described_class.new(url: 'https://google.com/hello?param=value', params: { my_param: :my_value })
      conn.get
      expect(conn.url.to_s).to eq 'https://google.com/hello?my_param=my_value&param=value'
    end
  end

  describe '#post' do
    before do
      stub_request(:post, "https://google.com/hello").
        with(
          body: "{\"supplejack\":\"jack\",\"page\":1}",
          headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent'=>'Supplejack Harvester v2.0'
          }).
        to_return(status: 200, body: "", headers: {})
    end

    it 'sends the provided params in the payload and NOT in the URL' do
      conn = described_class.new(url: 'https://google.com/hello', params: { supplejack: 'jack', page: '1' }, headers: {}, method: 'post')
      conn.post
    end
  end

  describe '#params' do
    it 'contains the params' do
      conn = described_class.new(
        url: 'https://google.com/hello',
        params: { param: :value }
      )
      expect(conn.params).to be_a Hash
      expect(conn.params).to eq({ 'param' => :value })
    end

    it 'contains the params from the given URL' do
      conn = described_class.new(url: 'https://google.com/hello?url_param=url_value')
      expect(conn.params).to eq({ 'url_param' => 'url_value' })
    end

    it 'contains the params from the given params' do
      conn = described_class.new(url: 'https://google.com/hello', params: { param: :value })
      expect(conn.params).to eq({ 'param' => :value })
    end

    it 'contains the params from the given URL and the given params' do
      conn = described_class.new(
        url: 'https://google.com/hello?url_param=url_value',
        params: { param: :value }
      )
      expect(conn.params).to eq({ 'param' => :value, 'url_param' => 'url_value' })
    end
  end

  describe '#headers' do
    it 'returns a hash' do
      conn = described_class.new(url: '/hello')
      expect(conn.headers).to be_a Hash
    end

    it 'returns the User-Agent by default' do
      conn = described_class.new(url: '/hello')
      expect(conn.headers).to eq({ 'User-Agent' => ENV.fetch('SJ_USER_AGENT', nil) })
    end

    it 'returns the User-Agent when nil is given' do
      conn = described_class.new(url: '/hello', headers: nil)
      expect(conn.headers).to eq({ 'User-Agent' => ENV.fetch('SJ_USER_AGENT', nil) })
    end

    it 'returns a custom User-Agent when needed' do
      conn = described_class.new(url: '/hello', headers: { 'User-Agent': 'Hello world' })
      expect(conn.headers).to eq({ 'User-Agent' => 'Hello world' })
    end

    it 'returns given headers with User-Agent algonside it' do
      conn = described_class.new(url: '/hello', headers: { 'My-Header': 'Hello world' })
      expect(conn.headers).to eq({ 'User-Agent' => ENV.fetch('SJ_USER_AGENT', nil), 'My-header' => 'Hello world' })
    end
  end

  describe '#get' do
    subject { described_class.new(url: 'hello') }

    before do
      stub_request(:get, 'http://google.com/hello').and_return(fake_response('test'))
    end

    it 'returns the response' do
      expect(described_class.new(url: 'http://google.com/hello').get).to be_a(Extraction::Response)
    end
  end
end
