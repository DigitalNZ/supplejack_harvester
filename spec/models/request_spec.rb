# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Request do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:http_method) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:extraction_definition) }
    it { is_expected.to have_many(:parameters) }
  end

  describe '#url' do
    let(:extraction_definition) { create(:extraction_definition, base_url: 'https://api.figshare.com') }
    let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }
    let(:request_two)           { create(:request, extraction_definition:) }

    it 'returns the URL based on the base url and slug params' do
      expect(request.url).to eq 'https://api.figshare.com/v1/articles/search'
    end

    it 'returns the URL without a trailing slash if there are no query parameters' do
      expect(request_two.url).to eq 'https://api.figshare.com'
    end
  end

  describe '#query_parameters' do
    let(:extraction_definition) { create(:extraction_definition, base_url: 'https://api.figshare.com') }
    let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }

    it 'returns a hash of query parameters' do
      expect(request.query_parameters).to eq(
        { 'search_for' => 'zealand', 'page' => '1', 'itemsPerPage' => '10' }
      )
    end
  end

  describe '#headers' do
    let(:extraction_definition) { create(:extraction_definition, base_url: 'https://api.figshare.com') }
    let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }

    it 'returns a hash of headers' do
      create(:parameter, kind: 'header', name: 'X-Forwarded-For', content: 'ab.cd.ef.gh', request:)

      expect(request.headers).to eq({ 'X-Forwarded-For' => 'ab.cd.ef.gh' })
    end
  end
end
