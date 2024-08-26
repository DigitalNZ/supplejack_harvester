# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::Documents do
  subject { extraction_job.documents }

  let(:pipeline) { create(:pipeline, :figshare) }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }
  let(:request) { create(:request, :figshare_initial_request, extraction_definition:) }

  before do
    # that's to test the display of results
    stub_figshare_harvest_requests(request)
    ExtractionWorker.new.perform(extraction_job.id)
  end

  describe '#initialize' do
    it 'saves the folder in the instance variables' do
      expect(subject.instance_variable_get(:@folder)).to eq extraction_job.extraction_folder
    end

    it 'sets the per_page to 1' do
      expect(subject.per_page).to eq 1
    end

    it 'sets the limit_value to nil' do
      expect(subject.limit_value).to be_nil
    end
  end

  describe '#[]' do
    it 'sets the current_page to 1 when nil is given' do
      subject[nil]
      expect(subject.current_page).to eq 1
    end

    it 'converts key to integer for the current_page' do
      subject['130']
      expect(subject.current_page).to eq 130
    end

    it 'returns nil when index is out of bounds' do
      expect(subject[200]).to be_nil
      expect(subject[0]).to be_nil
      expect(subject[-1]).to be_nil
    end

    it 'returns pages based on their page number, rather than their order in the file system' do
      documents = Extraction::Documents.new(Rails.root.join("spec/support/enrichment_documents"))

      expect(documents[1].file_path).to include('1/test_enrichment-extraction-118__thisisatestid1111111111111111116__000000001.json')
      expect(documents[2].file_path).to include('1/test_enrichment-extraction-118__thisisatestid1111111111111111117__000000002.json') 
      expect(documents[140].file_path).to include('2/test_enrichment-extraction-118__thisisatestid1111111111111111155__000000140.json')
    end
  end

  describe '#total_pages' do
    subject { Extraction::Documents.new(Rails.root.join("spec/support/enrichment_documents")) }

    it 'returns the number of documents into the folder' do
      expect(subject.total_pages).to eq (subject.total_folders.size - 1) * 100 + Dir.glob("#{subject.instance_variable_get(:@folder)}/#{subject.total_folders.size}/*").size
    end
  end
end
