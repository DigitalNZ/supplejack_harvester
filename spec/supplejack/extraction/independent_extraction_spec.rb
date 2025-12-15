# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::IndependentExtraction do
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) { create(:extraction_definition, pipeline:, base_url: 'https://example.com') }
  let!(:request) { create(:request, extraction_definition:) }
  let(:extraction_folder) { Rails.root.join('tmp/test_extraction').to_s }

  before { FileUtils.mkdir_p(extraction_folder) }
  after { FileUtils.rm_rf(extraction_folder) }

  it 'inherits from DocumentExtraction' do
    expect(described_class).to be < Extraction::DocumentExtraction
  end

  describe '#extract' do
    it 'fetches a document from the request URL' do
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

    it 'uses empty params when URL is overridden' do
      stub_request(:get, 'https://override.com/page').to_return(status: 200, body: 'ok')

      extraction = described_class.new(request, extraction_folder, 1, 'https://override.com/page')
      extraction.extract

      expect(a_request(:get, 'https://override.com/page')).to have_been_made
    end
  end

  describe '#save' do
    it 'saves the document to the extraction folder with correct page number' do
      stub_request(:get, /example\.com/).to_return(status: 200, body: '<html>content</html>')

      extraction = described_class.new(request, extraction_folder, 5)
      extraction.extract
      extraction.save

      files = Dir.glob("#{extraction_folder}/**/*.json")
      expect(files).not_to be_empty
      expect(files.first).to include('000000005')
    end
  end
end
