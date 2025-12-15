# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::IndependentExtractionExecution do
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) do
    create(:extraction_definition, pipeline:, base_url: 'https://example.com', independent_extraction: true)
  end
  let!(:request) { create(:request, extraction_definition:) }

  describe '#call' do
    context 'when performing initial independent extraction' do
      let(:extraction_job) { create(:extraction_job, extraction_definition:, is_independent_extraction: true) }
      let(:execution) { described_class.new(extraction_job) }

      it 'extracts links and saves them as documents' do
        mock_document = instance_double(Extraction::Document,
                                        body: '<html><a href="/page1">Link</a></html>',
                                        successful?: true)

        mock_extraction = instance_double(Extraction::IndependentExtraction,
                                          document: mock_document,
                                          extract_links: ['/page1'],
                                          save_link: true)
        allow(mock_extraction).to receive(:extract)
        allow(Extraction::IndependentExtraction).to receive(:new).and_return(mock_extraction)

        create(:automation_step,
               step_type: 'independent_extraction',
               extraction_definition:,
               independent_extraction_job: extraction_job,
               link_selector: 'a')

        expect(mock_extraction).to receive(:save_link).with('/page1', 1, 'https://example.com')

        execution.call
      end
    end

    context 'when extracting from a previous independent extraction' do
      let(:independent_extraction_job) do
        create(:extraction_job, extraction_definition:, is_independent_extraction: true)
      end

      context 'when this is another independent-extraction step' do
        let(:extraction_job) do
          create(:extraction_job,
                 extraction_definition:,
                 independent_extraction_job:,
                 is_independent_extraction: true)
        end
        let(:execution) { described_class.new(extraction_job) }

        it 'extracts links from fetched pages' do
          link_doc = double('Document', body: '{"url": "https://example.com/page1"}')
          documents = double('Documents', total_pages: 1)
          allow(documents).to receive(:[]).with(1).and_return(link_doc)

          allow(ExtractionJob).to receive(:find)
            .with(independent_extraction_job.id)
            .and_return(double('ExtractionJob', documents:))

          mock_extraction = instance_double(Extraction::IndependentExtraction,
                                            document: double(successful?: true),
                                            extract_links: ['/link1'],
                                            save_link: true)
          allow(mock_extraction).to receive(:extract)
          allow(Extraction::IndependentExtraction).to receive(:new).and_return(mock_extraction)

          create(:automation_step,
                 step_type: 'independent_extraction',
                 extraction_definition:,
                 independent_extraction_job: extraction_job,
                 link_selector: 'a')

          expect(mock_extraction).to receive(:save_link)

          execution.call
        end
      end

      context 'when this is a content extraction step' do
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
        let(:execution) { described_class.new(extraction_job) }

        it 'saves content and enqueues transformation' do
          link_doc = double('Document', body: '{"url": "https://example.com/page1"}')
          documents = double('Documents', total_pages: 1)
          allow(documents).to receive(:[]).with(1).and_return(link_doc)

          allow(ExtractionJob).to receive(:find)
            .with(independent_extraction_job.id)
            .and_return(double('ExtractionJob', documents:))

          mock_extraction = instance_double(Extraction::IndependentExtraction,
                                            document: double(successful?: true))
          allow(mock_extraction).to receive(:extract)
          allow(mock_extraction).to receive(:save)
          allow(Extraction::IndependentExtraction).to receive(:new).and_return(mock_extraction)

          allow(TransformationWorker).to receive(:perform_async_with_priority)

          expect(mock_extraction).to receive(:save)

          execution.call
        end
      end
    end
  end
end
