# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Parameter do
  describe 'associations' do
    it { is_expected.to belong_to(:request) }
  end

  describe 'kinds' do
    let(:query)  { create(:parameter, kind: 0) }
    let(:header) { create(:parameter, kind: 1) }
    let(:slug)   { create(:parameter, kind: 2) }

    it 'can be a query parameter' do
      expect(query.query?).to be true
    end

    it 'can be a header parameter' do
      expect(header.header?).to be true
    end

    it 'can be a slug parameter' do
      expect(slug.slug?).to be true
    end
  end

  describe '#content_type' do
    let(:static)       { create(:parameter, content_type: 0) }
    let(:dynamic)      { create(:parameter, content_type: 1) }
    let(:incremental)  { create(:parameter, content_type: 2) }

    it 'can be static' do
      expect(static.static?).to be true
    end

    it 'can be dynamic' do
      expect(dynamic.dynamic?).to be true
    end

    it 'can be incremental' do
      expect(incremental.incremental?).to be true
    end
  end

  describe '#to_h' do
    let(:query) { create(:parameter, kind: 'query', name: 'itemsPerPage', content: '30') }
    let(:slug)  { create(:parameter, kind: 'slug', content: 'articles') }

    it 'returns a hash of key => value' do
      expect(query.to_h).to eq(
        {
          'itemsPerPage' => '30'
        }
      )
    end

    it 'returns nothing for a slug parameter' do
      expect(slug.to_h).to be_nil
    end
  end

  describe '#evaluate' do
    let(:static)      { create(:parameter, kind: 'query', name: 'itemsPerPage') }
    let(:dynamic)     { create(:parameter, kind: 'query', name: 'itemsPerPage', content: '1 + 1', content_type: 1) }
    let(:incremental) { create(:parameter, kind: 'query', name: 'itemsPerPage', content: '12', content_type: 2) }
    let(:dynamic_response) do
      create(:parameter, kind: 'query', name: 'itemsPerPage', content: 'JSON.parse(response)["items_found"] + 10',
                         content_type: 1)
    end
    let(:erroring_dynamic_response) do
      create(:parameter, kind: 'query', name: 'itemsPerPage', content: 'raise',
                         content_type: 1)
    end
    let(:extraction_definition)         { create(:extraction_definition, :figshare) }
    let(:request)                       { create(:request, :figshare_initial_request, extraction_definition:) }
    let(:response)                      { Extraction::DocumentExtraction.new(request).extract }

    before do
      stub_figshare_harvest_requests(request)
    end

    it 'returns the unevaluated parameter if it is not dynamic' do
      expect(static.evaluate).to eq static
    end

    it 'returns the evaluated paramter if it is dynamic' do
      expect(dynamic.evaluate.content).to eq '2'
    end

    it 'returns the evaluated parameter based on a response' do
      expect(dynamic_response.evaluate(response).content).to eq '50'
    end

    it 'returns the incremented parameter if it is incremental' do
      expect(incremental.evaluate(response).content).to eq '22'
    end

    it 'returns a helpful message if the paramater has failed to be evaluated' do
      expect(erroring_dynamic_response.evaluate(response).content).to eq 'raise-evaluation-error'
    end
  end
end
