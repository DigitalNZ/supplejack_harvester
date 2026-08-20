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

  describe '#value_type' do
    it 'is a string by default' do
      expect(create(:parameter).value_string?).to be true
    end

    it 'can be an integer' do
      expect(create(:parameter, content: '30', value_type: 'integer').value_integer?).to be true
    end

    it 'can be a boolean' do
      expect(create(:parameter, content: 'true', value_type: 'boolean').value_boolean?).to be true
    end

    it 'can be JSON' do
      expect(create(:parameter, content: '{"status": "deleted"}', value_type: 'json').value_json?).to be true
    end
  end

  describe 'validations' do
    it 'refuses content that is not a whole number for an integer' do
      parameter = build(:parameter, content: 'thirty', value_type: 'integer')

      expect(parameter).not_to be_valid
      expect(parameter.errors[:content]).to eq ['must be a whole number']
    end

    it 'refuses content that is not true or false for a boolean' do
      parameter = build(:parameter, content: 'yes', value_type: 'boolean')

      expect(parameter).not_to be_valid
      expect(parameter.errors[:content]).to eq ['must be true or false']
    end

    it 'refuses content that is not valid JSON for a JSON value' do
      parameter = build(:parameter, content: '{"status": deleted}', value_type: 'json')

      expect(parameter).not_to be_valid
      expect(parameter.errors[:content].first).to start_with 'must be valid JSON'
    end

    it 'accepts a JSON value that is a whole object' do
      expect(build(:parameter, content: '{"status": "deleted"}', value_type: 'json')).to be_valid
    end

    # The editor saves the type on its own, so a parameter that is still being filled in
    # has nothing to check the type against yet.
    it 'accepts blank content whatever the type says' do
      expect(build(:parameter, content: '', value_type: 'json')).to be_valid
    end

    it 'refuses a type on a dynamic parameter, which is typed by what it returns' do
      parameter = build(:parameter, content: '{"status": "deleted"}', content_type: 'dynamic', value_type: 'json')

      expect(parameter).not_to be_valid
      expect(parameter.errors[:value_type]).to eq ['can only be declared by a static query or header parameter']
    end

    it 'refuses a type on a slug parameter, which is a segment of the URL' do
      parameter = build(:parameter, content: '2', kind: 'slug', value_type: 'integer')

      expect(parameter).not_to be_valid
      expect(parameter.errors[:value_type]).to eq ['can only be declared by a static query or header parameter']
    end

    it 'accepts a dynamic parameter that declares no type' do
      expect(build(:parameter, content: '1 + 1', content_type: 'dynamic')).to be_valid
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

    it 'returns the content of a static parameter' do
      expect(static.evaluate.to_h).to eq({ 'itemsPerPage' => static.content })
    end

    it 'returns the evaluated parameter if it is dynamic' do
      expect(dynamic.evaluate.value).to eq 2
    end

    it 'returns the evaluated parameter based on a response' do
      expect(dynamic_response.evaluate(response).value).to eq 50
    end

    it 'returns the incremented parameter if it is incremental' do
      expect(incremental.evaluate(response).value).to eq 22
    end

    it 'returns a helpful message if the paramater has failed to be evaluated' do
      expect(erroring_dynamic_response.evaluate(response).value).to eq 'raise-evaluation-error'
    end

    # The whole point of the value: a Hash used to be cast to a String by the content
    # column, reaching the content source as "{record: {status: :deleted}}".
    context 'when a dynamic parameter returns a nested value' do
      let(:nested) do
        create(:parameter, kind: 'query', name: 'record', content: '{ record: { status: :deleted } }',
                           content_type: 1)
      end

      it 'keeps the value nested' do
        expect(nested.evaluate.value).to eq({ record: { status: :deleted } })
      end
    end

    context 'when a static parameter declares a type' do
      it 'reads JSON content as the structure it describes' do
        parameter = create(:parameter, kind: 'query', name: 'record', content: '{"status": "deleted"}',
                                       value_type: 'json')

        expect(parameter.evaluate.to_h).to eq({ 'record' => { 'status' => 'deleted' } })
      end

      it 'reads integer content as a number' do
        parameter = create(:parameter, kind: 'query', name: 'page', content: '30', value_type: 'integer')

        expect(parameter.evaluate.value).to eq 30
      end

      it 'reads boolean content as a boolean' do
        parameter = create(:parameter, kind: 'query', name: 'active', content: 'false', value_type: 'boolean')

        expect(parameter.evaluate.value).to be false
      end

      it 'reads a JSON null as nil' do
        parameter = create(:parameter, kind: 'query', name: 'record_includes', content: 'null', value_type: 'json')

        expect(parameter.evaluate.value).to be_nil
      end
    end
  end
end
