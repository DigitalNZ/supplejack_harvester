# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::IndependentExtractionHelpers do
  # Test through the actual Execution class which includes this module
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) do
    create(:extraction_definition, pipeline:, base_url: 'https://example.com', independent_extraction: true)
  end
  let!(:request) { create(:request, extraction_definition:) }

  describe '#perform_independent_extraction' do
    let(:extraction_job) { create(:extraction_job, extraction_definition:, is_independent_extraction: true) }
    let(:execution) { Extraction::Execution.new(extraction_job, extraction_definition) }

    it 'extracts links from the document and saves them' do
      mock_document = instance_double(Extraction::Document,
                                      body: '{"test": "data"}',
                                      successful?: true,
                                      status: 200)

      allow(execution).to receive(:extract) do
        execution.instance_variable_set(:@de, double('DocumentExtraction', document: mock_document))
      end
      allow(execution).to receive(:extract_links_from_document)
        .with(mock_document)
        .and_return(%w[https://example.com/page1 https://example.com/page2])
      allow(execution).to receive(:save_link_as_document)

      expect(execution).to receive(:save_link_as_document).with('https://example.com/page1', 1)
      expect(execution).to receive(:save_link_as_document).with('https://example.com/page2', 2)

      execution.perform_independent_extraction
    end

    it 'does nothing when document is blank' do
      allow(execution).to receive(:extract) do
        execution.instance_variable_set(:@de, double('DocumentExtraction', document: nil))
      end

      expect(execution).not_to receive(:extract_links_from_document)
      expect(execution).not_to receive(:save_link_as_document)

      execution.perform_independent_extraction
    end
  end

  describe '#perform_extraction_from_independent_extraction' do
    let(:independent_extraction_job) do
      create(:extraction_job, extraction_definition:, is_independent_extraction: true)
    end

    context 'when extraction job is an independent-extraction step' do
      let(:extraction_job) do
        create(:extraction_job,
               extraction_definition:,
               independent_extraction_job:,
               is_independent_extraction: true)
      end
      let(:execution) { Extraction::Execution.new(extraction_job, extraction_definition) }

      it 'extracts links from each fetched page and saves them' do
        link_doc = double('Document',
                          body: '{"url": "https://example.com/page1"}',
                          successful?: true)
        documents = double('Documents', total_pages: 1)
        allow(documents).to receive(:[]).with(1).and_return(link_doc)

        mock_independent_extraction_job = double('ExtractionJob', documents:)
        allow(ExtractionJob).to receive(:find)
          .with(independent_extraction_job.id)
          .and_return(mock_independent_extraction_job)

        fetched_doc = double('FetchedDocument', successful?: true, status: 200, body: '<html>...</html>')
        mock_de = double('DocumentExtraction', document: fetched_doc)
        allow(mock_de).to receive(:extract).and_return(nil)
        allow(Extraction::DocumentExtraction).to receive(:new).and_return(mock_de)

        allow(execution).to receive(:extract_links_from_document)
          .with(fetched_doc)
          .and_return(['https://example.com/link1'])
        allow(execution).to receive(:save_link_as_document)
        allow(execution).to receive(:throttle)

        expect(execution).to receive(:save_link_as_document).with('https://example.com/link1', 1)

        execution.perform_extraction_from_independent_extraction
      end
    end

    context 'when extraction job is a pipeline step (not independent-extraction)' do
      let(:destination) { create(:destination) }
      let(:pipeline_job) { create(:pipeline_job, pipeline:, destination:) }
      let(:harvest_definition) { create(:harvest_definition, pipeline:, extraction_definition:) }
      let(:harvest_job) { create(:harvest_job, pipeline_job:, harvest_definition:) }
      let(:extraction_job) do
        create(:extraction_job,
               extraction_definition:,
               independent_extraction_job:,
               is_independent_extraction: false,
               harvest_job:)
      end
      let!(:harvest_report) { create(:harvest_report, pipeline_job:, harvest_job:) }
      let(:execution) { Extraction::Execution.new(extraction_job, extraction_definition) }

      it 'saves content from each fetched page and enqueues transformation' do
        link_doc = double('Document',
                          body: '{"url": "https://example.com/page1"}',
                          successful?: true)
        documents = double('Documents', total_pages: 1)
        allow(documents).to receive(:[]).with(1).and_return(link_doc)

        mock_independent_extraction_job = double('ExtractionJob', documents:)
        allow(ExtractionJob).to receive(:find)
          .with(independent_extraction_job.id)
          .and_return(mock_independent_extraction_job)

        fetched_doc = double('FetchedDocument', successful?: true, status: 200, body: '<html>content</html>')
        mock_de = double('DocumentExtraction', document: fetched_doc)
        allow(mock_de).to receive(:extract).and_return(nil)
        allow(mock_de).to receive(:save)
        allow(Extraction::DocumentExtraction).to receive(:new).and_return(mock_de)

        allow(execution).to receive(:throttle)
        allow(TransformationWorker).to receive(:perform_async_with_priority)

        expect(mock_de).to receive(:save)

        execution.perform_extraction_from_independent_extraction
      end
    end
  end

  describe 'private methods' do
    let(:extraction_job) { create(:extraction_job, extraction_definition:, is_independent_extraction: true) }
    let(:execution) { Extraction::Execution.new(extraction_job, extraction_definition) }

    describe '#save_links_as_documents' do
      it 'saves each link as a document with incrementing page numbers' do
        links = ['https://example.com/1', 'https://example.com/2', 'https://example.com/3']

        allow(execution).to receive(:save_link_as_document)

        expect(execution).to receive(:save_link_as_document).with('https://example.com/1', 1)
        expect(execution).to receive(:save_link_as_document).with('https://example.com/2', 2)
        expect(execution).to receive(:save_link_as_document).with('https://example.com/3', 3)

        execution.send(:save_links_as_documents, links)
      end
    end
  end
end
