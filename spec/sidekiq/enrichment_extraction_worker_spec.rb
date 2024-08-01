# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnrichmentExtractionWorker, type: :job do
  let(:subject)               { described_class.new }

  let(:pipeline)              { create(:pipeline, :figshare) }
  let(:destination)           { create(:destination) }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let(:extraction_job)        { create(:extraction_job, extraction_definition:, status: 'queued') }
  let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }
  let(:api_record)           { Extraction::ApiRecord.new('') }

  describe '#perform' do
    before { stub_figshare_harvest_requests(request) }

    it 'creates a new enrichment extraction' do
      page = 1

      expect(Extraction::EnrichmentExtraction).to receive(:new).with(request, api_record, page, extraction_job.extraction_folder).and_call_original

      subject.perform(request, api_record, page, extraction_job.extraction_folder)
    end

    context 'when the enrichment extraction is valid' do
      before do
        allow_any_instance_of(Extraction::EnrichmentExtraction).to receive(:valid?).and_return(true)
      end

      it 'calls extract and save' do
        expect_any_instance_of(Extraction::EnrichmentExtraction).to receive(:extract_and_save)

        subject.perform(request, api_record, 1, extraction_job.extraction_folder)
      end
    end

    context 'when the enrichment extraction is not valid' do
      before do
        allow_any_instance_of(Extraction::EnrichmentExtraction).to receive(:valid?).and_return(false)
      end

      it 'does not call extract and save' do
        expect_any_instance_of(Extraction::EnrichmentExtraction).not_to receive(:extract_and_save)

        subject.perform(request, api_record, 1, extraction_job.extraction_folder)
      end
    end
  end
end