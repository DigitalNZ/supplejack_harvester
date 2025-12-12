# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::IndependentExtractionHelpers do
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) { create(:extraction_definition, pipeline:, base_url: 'https://example.com', independent_extraction: true) }
  let(:request) { create(:request, extraction_definition:) }

  # Create a test class that includes the module and the parent module methods
  let(:test_class) do
    Class.new do
      include Extraction::IndependentExtractionHelpers

      attr_accessor :extraction_job, :extraction_definition, :harvest_job, :harvest_report, :de, :previous_request

      def initialize(extraction_job, extraction_definition)
        @extraction_job = extraction_job
        @extraction_definition = extraction_definition
        @harvest_job = extraction_job.harvest_job
        @harvest_report = @harvest_job&.harvest_report
      end

      # Mock methods that would come from Execution
      def extract(_request)
        # Simulated extraction
      end

      def extract_links_from_document(_document)
        # Simulated link extraction
        []
      end

      def save_link_as_document(_link_url, _page_number)
        # Simulated save
      end

      def throttle
        # No-op for tests
      end

      def execution_cancelled?
        false
      end

      def independent_extraction_link_document?(doc)
        return false unless doc

        body = JSON.parse(doc.body)
        body.is_a?(Hash) && body.key?('url') && body.keys.size == 1
      rescue JSON::ParserError
        false
      end

      def extract_url_from_independent_extraction_document(document)
        body = JSON.parse(document.body)
        body['url']
      rescue JSON::ParserError
        nil
      end

      def build_request_for_url(url)
        OpenStruct.new(url:)
      end

      def duplicate_document_extracted?
        false
      end

      def enqueue_record_transformation
        # Simulated enqueue
      end
    end
  end

  describe '#perform_independent_extraction' do
    let(:extraction_job) { create(:extraction_job, extraction_definition:, is_independent_extraction: true) }
    let(:subject) { test_class.new(extraction_job, extraction_definition) }

    it 'extracts links from the document and saves them' do
      mock_document = double('Document', body: '{"test": "data"}', successful?: true)
      subject.de = double('DocumentExtraction', document: mock_document)

      expect(subject).to receive(:extract).with(anything)
      expect(subject).to receive(:extract_links_from_document).with(mock_document).and_return(%w[https://example.com/page1 https://example.com/page2])
      expect(subject).to receive(:save_link_as_document).with('https://example.com/page1', 1)
      expect(subject).to receive(:save_link_as_document).with('https://example.com/page2', 2)

      subject.perform_independent_extraction
    end

    it 'does nothing when document is blank' do
      subject.de = double('DocumentExtraction', document: nil)

      expect(subject).to receive(:extract).with(anything)
      expect(subject).not_to receive(:extract_links_from_document)
      expect(subject).not_to receive(:save_link_as_document)

      subject.perform_independent_extraction
    end
  end

  describe '#perform_extraction_from_independent_extraction' do
    let(:independent_extraction_job) { create(:extraction_job, extraction_definition:, is_independent_extraction: true) }

    context 'when extraction job is an independent-extraction step' do
      let(:extraction_job) do
        create(:extraction_job, extraction_definition:, independent_extraction_job:, is_independent_extraction: true)
      end
      let(:subject) { test_class.new(extraction_job, extraction_definition) }

      it 'extracts links from each fetched page and saves them' do
        # Create mock documents representing independent-extraction links
        link_doc = double('Document',
                          body: '{"url": "https://example.com/page1"}',
                          successful?: true)
        documents = double('Documents', total_pages: 1)
        allow(documents).to receive(:[]).with(1).and_return(link_doc)

        # Stub ExtractionJob.find to return a mock that returns our mock documents
        mock_independent_extraction_job = double('ExtractionJob', documents:)
        allow(ExtractionJob).to receive(:find).with(independent_extraction_job.id).and_return(mock_independent_extraction_job)

        # Mock the DocumentExtraction that gets created in fetch_document_for_page
        fetched_doc = double('FetchedDocument', successful?: true, body: '<html>...</html>')
        mock_de = double('DocumentExtraction', document: fetched_doc)
        allow(mock_de).to receive(:extract).and_return(nil)

        allow(Extraction::DocumentExtraction).to receive(:new).and_return(mock_de)

        # Mock extract_links_from_document to return extracted links
        allow(subject).to receive(:extract_links_from_document).with(fetched_doc).and_return(['https://example.com/link1'])

        # Expect save_link_as_document to be called with extracted links
        expect(subject).to receive(:save_link_as_document).with('https://example.com/link1', 1)

        subject.perform_extraction_from_independent_extraction
      end
    end

    context 'when extraction job is a pipeline step (not independent-extraction)' do
      let(:destination) { create(:destination) }
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, extraction_definition:) }
      let(:harvest_job) { create(:harvest_job, pipeline_job:, harvest_definition:) }
      let(:extraction_job) do
        create(:extraction_job, extraction_definition:, independent_extraction_job:, is_independent_extraction: false, harvest_job:)
      end
      let!(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:) }
      let(:subject) { test_class.new(extraction_job, extraction_definition) }

      it 'saves content from each fetched page and enqueues transformation' do
        # Create mock documents representing independent-extraction links
        link_doc = double('Document',
                          body: '{"url": "https://example.com/page1"}',
                          successful?: true)
        documents = double('Documents', total_pages: 1)
        allow(documents).to receive(:[]).with(1).and_return(link_doc)

        # Stub ExtractionJob.find to return a mock that returns our mock documents
        mock_independent_extraction_job = double('ExtractionJob', documents:)
        allow(ExtractionJob).to receive(:find).with(independent_extraction_job.id).and_return(mock_independent_extraction_job)

        # Mock the DocumentExtraction that gets created in fetch_document_for_page
        fetched_doc = double('FetchedDocument', successful?: true, body: '<html>content</html>')
        mock_de = double('DocumentExtraction', document: fetched_doc)
        allow(mock_de).to receive(:extract).and_return(nil)
        expect(mock_de).to receive(:save)

        allow(Extraction::DocumentExtraction).to receive(:new).and_return(mock_de)

        expect(subject).to receive(:enqueue_record_transformation)

        subject.perform_extraction_from_independent_extraction
      end
    end
  end

  describe 'private methods' do
    let(:extraction_job) { create(:extraction_job, extraction_definition:, is_independent_extraction: true) }
    let(:subject) { test_class.new(extraction_job, extraction_definition) }

    describe '#save_links_as_documents' do
      it 'saves each link as a document with incrementing page numbers' do
        links = ['https://example.com/1', 'https://example.com/2', 'https://example.com/3']

        expect(subject).to receive(:save_link_as_document).with('https://example.com/1', 1)
        expect(subject).to receive(:save_link_as_document).with('https://example.com/2', 2)
        expect(subject).to receive(:save_link_as_document).with('https://example.com/3', 3)

        subject.send(:save_links_as_documents, links)
      end
    end
  end
end

