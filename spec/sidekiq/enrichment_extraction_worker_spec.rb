# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnrichmentExtractionWorker, type: :job do
  let(:subject)               { described_class.new }

  let(:pipeline)              { create(:pipeline, :figshare) }
  let(:destination)           { create(:destination) }
  let(:harvest_definition)    { create(:harvest_definition, pipeline:) }
  let(:pipeline_job)          { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_job)           { create(:harvest_job, harvest_definition:, pipeline_job:) }
  let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, throttle: 0) }
  let(:extraction_job)        { create(:extraction_job, extraction_definition:, harvest_job:, status: 'queued') }
  let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }
  let(:api_record)            { Extraction::ApiRecord.new('') }

  describe '#perform' do
    before do 
      stub_figshare_harvest_requests(request)
      stub_figshare_enrichment_page1(destination)
    end

    it 'creates a new enrichment extraction' do
      page = 1

      expect(Extraction::EnrichmentExtraction).to receive(:new).with(request, api_record, page, extraction_job.extraction_folder).and_call_original

      subject.perform(extraction_definition, extraction_job, api_record, page)
    end

    context 'when the enrichment extraction is valid' do
      before do
        allow_any_instance_of(Extraction::EnrichmentExtraction).to receive(:valid?).and_return(true)
      end

      it 'calls extract and save' do
        expect_any_instance_of(Extraction::EnrichmentExtraction).to receive(:extract_and_save).and_call_original

        subject.perform(extraction_definition, extraction_job, api_record, 1)
      end

      it 'enqueues a record transformation' do
        expect(TransformationWorker).to receive(:perform_async)

        subject.perform(extraction_definition, extraction_job, api_record, 1)
      end
    end

    context 'when the enrichment extraction is not valid' do
      before do
        allow_any_instance_of(Extraction::EnrichmentExtraction).to receive(:valid?).and_return(false)
      end

      it 'does not call extract and save' do
        expect_any_instance_of(Extraction::EnrichmentExtraction).not_to receive(:extract_and_save).and_call_original

        subject.perform(extraction_definition, extraction_job, api_record, 1)
      end

      it 'does not enqueue a record transformation' do
        expect(TransformationWorker).not_to receive(:perform_async)

        subject.perform(extraction_definition, extraction_job, api_record, 1)
      end
    end
  end
end