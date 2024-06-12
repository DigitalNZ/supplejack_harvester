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
      subject['10']
      expect(subject.current_page).to eq 10
    end

    it 'returns nil when index is out of bounds' do
      expect(subject[10]).to be_nil
      expect(subject[0]).to be_nil
      expect(subject[-1]).to be_nil
    end

    it 'returns pages based on their page number, rather than their order in the file system' do
      documents = Extraction::Documents.new(Rails.root.join("spec/support/enrichment_documents"))

      expect(documents[1].file_path).to include('test_enrichment-extraction-118__thisisatestid111111111111111115__000000001.json')
      expect(documents[2].file_path).to include('test_enrichment-extraction-118__thisisatestid111111111111111113__000000002.json') 
      expect(documents[3].file_path).to include('test_enrichment-extraction-118__thisisatestid111111111111111114__000000003.json')
      expect(documents[4].file_path).to include('test_enrichment-extraction-118__thisisatestid111111111111111112__000000004.json')
      expect(documents[5].file_path).to include('test_enrichment-extraction-118__thisisatestid111111111111111111__000000005.json')
    end
  end

  describe '#total_pages' do
    it 'returns the number of documents into the folder' do
      expect(subject.total_pages).to eq Dir.glob("#{extraction_job.extraction_folder}/*").length
    end
  end
end
