# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Extraction::Documents do
  subject { extraction_job.documents }

  let(:content_partner) { create(:content_partner, :ngataonga) }
  let(:extraction_definition) { content_partner.extraction_definitions.first }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }

  before do
    # that's to test the display of results
    stub_ngataonga_harvest_requests(extraction_definition)
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
      expect(subject.limit_value).to eq nil
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
      expect(subject[10]).to eq nil
      expect(subject[0]).to eq nil
      expect(subject[-1]).to eq nil
    end
  end

  describe '#total_pages' do
    it 'returns the number of documents into the folder' do
      expect(subject.total_pages).to eq Dir.glob("#{extraction_job.extraction_folder}/*").length
    end
  end
end
