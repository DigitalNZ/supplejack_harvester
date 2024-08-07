# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionContext do
  subject(:context) do
    described_class.new(
      extraction_definition,
      extraction_job,
      enrichment_extraction,
      harvest_job,
      api_record,
      page
    )
  end

  let(:pipeline)              { create(:pipeline, :figshare) }
  let(:destination)           { create(:destination) }
  let(:harvest_definition)    { create(:harvest_definition, pipeline:) }
  let(:pipeline_job)          { create(:pipeline_job, pipeline:, destination:) }
  let(:extraction_definition) { create(:extraction_definition, :enrichment, destination:, throttle: 0) }
  let(:extraction_job)        { create(:extraction_job, extraction_definition:, harvest_job:, status: 'queued') }
  let(:request)               { create(:request, :figshare_initial_request, extraction_definition:) }
  let(:api_record)            { build(:api_record) }
  let(:page)                  { 1 }
  let(:enrichment_extraction) do
    Extraction::EnrichmentExtraction.new(request, api_record, page, extraction_job.extraction_folder)
  end
  let(:harvest_job) { create(:harvest_job, harvest_definition:, pipeline_job:) }

  describe '#initialize' do
    it 'assigns extraction_definition' do
      expect(context.extraction_definition).to eq(extraction_definition)
    end

    it 'assigns extraction_job' do
      expect(context.extraction_job).to eq(extraction_job)
    end

    it 'assigns enrichment_extraction' do
      expect(context.enrichment_extraction).to eq(enrichment_extraction)
    end

    it 'assigns harvest_job' do
      expect(context.harvest_job).to eq(harvest_job)
    end

    it 'assigns api_record' do
      expect(context.api_record).to eq(api_record)
    end

    it 'assigns page' do
      expect(context.page).to eq(page)
    end
  end
end
