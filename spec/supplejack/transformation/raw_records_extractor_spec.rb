# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transformation::RawRecordsExtractor do
  let(:pipeline)                  { create(:pipeline, :figshare) }
  let(:extraction_definition)      { pipeline.harvest.extraction_definition }
  let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition)  { create(:transformation_definition, extraction_job:, record_selector: '$..items') }
  let(:request)                   { create(:request, :figshare_initial_request, extraction_definition:) }

  subject { described_class.new(transformation_definition, extraction_job) }

  before do
    stub_figshare_harvest_requests(request)
    ExtractionWorker.new.perform(extraction_job.id)
  end

  describe '#records' do
    it 'returns records extracted using the record_selector' do
      expect(subject.records(1)).not_to be_empty
    end

    context 'when the document body is XML but the format is JSON' do
      let(:xml_body) { '<?xml version="1.0" encoding="utf-8"?><error>Service unavailable</error>' }
      let(:document) { instance_double(Extraction::Document, body: xml_body, size_in_bytes: 100) }
      let(:documents) { instance_double(Extraction::Documents) }

      before do
        allow(extraction_job).to receive(:documents).and_return(documents)
        allow(documents).to receive(:[]).with(1).and_return(document)
      end

      it 'returns an empty array instead of raising' do
        expect(subject.records(1)).to eq []
      end
    end

    context 'when the page is larger than 10MB but still contains valid records' do
      let(:body)      { { items: [{ id: 1 }, { id: 2 }] }.to_json }
      let(:document)  { instance_double(Extraction::Document, body:, size_in_bytes: 50.megabytes) }
      let(:documents) { instance_double(Extraction::Documents) }

      before do
        allow(extraction_job).to receive(:documents).and_return(documents)
        allow(documents).to receive(:[]).with(1).and_return(document)
      end

      it 'extracts the records instead of silently dropping the page' do
        expect(subject.records(1)).not_to be_empty
      end
    end

    context 'when the page exceeds the maximum parseable size' do
      let(:body)      { { items: [{ id: 1 }] }.to_json }
      let(:document)  { instance_double(Extraction::Document, body:, size_in_bytes: 200.megabytes) }
      let(:documents) { instance_double(Extraction::Documents) }

      before do
        allow(extraction_job).to receive(:documents).and_return(documents)
        allow(documents).to receive(:[]).with(1).and_return(document)
      end

      it 'logs a warning and returns an empty array rather than silently dropping it' do
        expect(Rails.logger).to receive(:warn).with(/exceeds the maximum/)
        expect(subject.records(1)).to eq []
      end
    end
  end
end
