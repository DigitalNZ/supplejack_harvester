# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionParams do
  let(:extraction_definition) { double("ExtractionDefinition") }
  let(:extraction_job) { double("ExtractionJob") }
  let(:harvest_job) { double("HarvestJob") }
  let(:api_record) { double("APIRecord") }
  let(:page) { double("Page") }

  subject { described_class.new(extraction_definition, extraction_job, harvest_job, api_record, page) }

  describe '#initialize' do
    it 'assigns extraction_definition' do
      expect(subject.extraction_definition).to eq(extraction_definition)
    end

    it 'assigns extraction_job' do
      expect(subject.extraction_job).to eq(extraction_job)
    end

    it 'assigns harvest_job' do
      expect(subject.harvest_job).to eq(harvest_job)
    end

    it 'assigns api_record' do
      expect(subject.api_record).to eq(api_record)
    end

    it 'assigns page' do
      expect(subject.page).to eq(page)
    end
  end
end