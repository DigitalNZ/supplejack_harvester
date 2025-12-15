# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::IndependentExtraction do
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) { create(:extraction_definition, pipeline:, base_url: 'https://example.com') }
  let!(:request) { create(:request, extraction_definition:) }
  let(:extraction_folder) { Rails.root.join('tmp/test_extraction').to_s }

  before { FileUtils.mkdir_p(extraction_folder) }
  after { FileUtils.rm_rf(extraction_folder) }

  describe '#extract' do
    it 'fetches a document from the URL' do
      stub_request(:get, /example\.com/).to_return(status: 200, body: '<html>content</html>')

      extraction = described_class.new(request, extraction_folder)
      extraction.extract

      expect(extraction.document).to be_present
      expect(extraction.document.body).to include('content')
    end

    it 'uses the override URL when provided' do
      stub_request(:get, 'https://override.com/page').to_return(status: 200, body: '<html>override</html>')

      extraction = described_class.new(request, extraction_folder, 1, 'https://override.com/page')
      extraction.extract

      expect(extraction.document.body).to include('override')
    end
  end

  describe '#extract_links' do
    let(:extraction) { described_class.new(request, extraction_folder) }

    context 'with CSS selector' do
      it 'extracts href attributes from anchor elements' do
        stub_request(:get, /example\.com/).to_return(
          status: 200,
          body: '<html><a href="/page1">Link1</a><a href="/page2">Link2</a></html>'
        )
        extraction.extract

        expect(extraction.extract_links('a')).to contain_exactly('/page1', '/page2')
      end
    end

    context 'with XPath selector' do
      it 'extracts using xpath' do
        stub_request(:get, /example\.com/).to_return(
          status: 200,
          body: '<html><body><a href="/xpath-link">Link</a></body></html>'
        )
        extraction.extract

        expect(extraction.extract_links('//a/@href')).to eq(['/xpath-link'])
      end
    end

    context 'with JSONPath selector' do
      it 'extracts values using JSONPath' do
        stub_request(:get, /example\.com/).to_return(
          status: 200,
          body: '{"items": [{"url": "https://example.com/1"}, {"url": "https://example.com/2"}]}'
        )
        extraction.extract

        expect(extraction.extract_links('$.items[*].url')).to contain_exactly(
          'https://example.com/1', 'https://example.com/2'
        )
      end
    end

    it 'returns empty array for blank selector' do
      stub_request(:get, /example\.com/).to_return(status: 200, body: '<html></html>')
      extraction.extract

      expect(extraction.extract_links(nil)).to eq([])
    end
  end

  describe '#save_link' do
    it 'saves a link document to the extraction folder' do
      stub_request(:get, /example\.com/).to_return(status: 200, body: '<html></html>')

      extraction = described_class.new(request, extraction_folder)
      extraction.extract
      extraction.save_link('/page', 1, 'https://example.com')

      files = Dir.glob("#{extraction_folder}/**/*.json")
      expect(files).not_to be_empty

      content = JSON.parse(File.read(files.first))
      expect(content['body']).to include('url')
    end

    it 'normalizes relative URLs' do
      stub_request(:get, /example\.com/).to_return(status: 200, body: '<html></html>')

      extraction = described_class.new(request, extraction_folder)
      extraction.extract
      extraction.save_link('/relative/path', 1, 'https://example.com')

      files = Dir.glob("#{extraction_folder}/**/*.json")
      content = JSON.parse(File.read(files.first))
      body = JSON.parse(content['body'])

      expect(body['url']).to eq('https://example.com/relative/path')
    end
  end
end
