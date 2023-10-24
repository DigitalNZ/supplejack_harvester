# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::EnrichmentExtraction do
  subject { described_class.new(request_two, record, 1, extraction_job.extraction_folder) }

  let(:extraction_job) { create(:extraction_job) }
  let(:destination) { create(:destination) }
  let(:ed) { create(:extraction_definition, :enrichment, destination:, extraction_jobs: [extraction_job]) }
  let(:re) { Extraction::RecordExtraction.new(request_one, 1).extract }
  let(:records) { JSON.parse(re.body)['records'] }
  let(:record)  { Extraction::ApiRecord.new(records.first) }

  let!(:request_one) { create(:request, extraction_definition: ed) }
  let!(:request_two) { create(:request, extraction_definition: ed) }

  let!(:parameter)   { create(:parameter, content: "response['dc_identifier'].first", kind: 'slug', request: request_two, content_type: 'dynamic') }

  before do
    stub_figshare_enrichment_page1(destination)
    stub_figshare_enrichment_page2(destination)
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

        expect(File.exist?(subject.send(:file_path))).to be true
      end
    end

    context 'when there is no extraction_folder' do
      it 'returns an extracted document from a content source' do
        doc = described_class.new(request_two, record, 1)
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

  describe '#valid?' do
    it 'returns true if the provided enrichment url returns something from the record' do
      expect(subject.valid?).to be true
    end

    it 'returns false if the provided enrichment url returns nothing from the record' do
      record = Extraction::ApiRecord.new({ 'hello' => 'goodbye'} )

      expect(described_class.new(request_two, record, 1, extraction_job.extraction_folder).valid?).to be false
    end
  end
end
