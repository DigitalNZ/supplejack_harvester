# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::EnrichmentExtraction do
  let(:extraction_job) { create(:extraction_job) }
  let(:destination) { create(:destination) }
  let(:ed) { create(:extraction_definition, :enrichment, destination:, extraction_jobs: [extraction_job]) }
  let(:re) { Extraction::RecordExtraction.new(ed, 1).extract }
  let(:records) { records = JSON.parse(re.body)['records'] }
  let(:subject) { described_class.new(ed, records.first, 1, extraction_job.extraction_folder) }

  before do
    stub_figshare_enrichment_page_1(destination)
  end

  describe '#extract' do
    it 'fetches additional metadata based on the provided record' do
      expect(subject.extract).to be_a(Extraction::Document)
    end
  end

  describe '#save' do
    context 'when there is a document to save' do
      it 'saves the document to the filepath' do
        subject.extract
        subject.save

        expect(File.exist?(subject.send(:file_path))).to eq true
      end
    end

    context 'when there is no extraction_folder' do
      it 'returns an extracted document from a content partner' do
        doc = described_class.new(ed, records.first, 1)
        expect { doc.save }.to raise_error(ArgumentError, 'extraction_folder was not provided in #new')
      end
    end

    context 'when there is not a document to save' do
      it 'returns a helpful error message' do
        expect { subject.save }.to raise_error('#extract must be called before #save AbstractExtraction')
      end
    end
  end

  describe '#extract_and_save' do
    it 'calls both extract and save' do
      expect(subject).to receive(:extract)
      expect(subject).to receive(:save)

      subject.extract_and_save
    end
  end
end
