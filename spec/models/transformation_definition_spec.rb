# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransformationDefinition, type: :model do
  let(:content_source) { create(:content_source, :ngataonga, name: 'National Library of New Zealand') }
  let(:extraction_definition) { content_source.extraction_definitions.first }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }
  let(:subject) { create(:transformation_definition, content_source:, extraction_job:) }

  let!(:field_one) do
    create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition: subject)
  end
  let!(:field_two) do
    create(:field, name: 'source', block: "JsonPath.new('source').on(record).first", transformation_definition: subject)
  end
  let!(:field_three) do
    create(:field, name: 'dc_identifier', block: "JsonPath.new('reference_number').on(record).first",
                   transformation_definition: subject)
  end
  let!(:field_four) { create(:field, name: 'landing_url', block: '"http://www.ngataonga.org.nz/collections/catalogue/catalogue-item?record_id=#{record[\'record_id\']}"', transformation_definition: subject) }

  before do
    # that's to test the display of results
    stub_ngataonga_harvest_requests(extraction_definition)
    ExtractionWorker.new.perform(extraction_job.id)
  end

  describe '#attributes' do
    it 'has a record selector' do
      expect(subject.record_selector).to eq '$..results'
    end

    it 'belongs to a content source' do
      expect(subject.content_source).to eq content_source
    end

    it 'has a job' do
      expect(subject.extraction_job).to eq extraction_job
    end
  end

  describe '#records' do
    it 'returns the records from the job documents' do
      expect(subject.records.first).to have_key 'record_id'
    end
  end

  describe "#validation" do
    it 'cannot be a copy of itself' do
      subject.original_transformation_definition = subject
      expect(subject).not_to be_valid
    end
  end

  describe "#copy?" do
    let(:original) { create(:transformation_definition) }
    let(:copy)     { create(:transformation_definition, original_transformation_definition: original) }

    it 'returns true if the transformation definition is a copy' do
      expect(copy.copy?).to be true
    end

    it 'returns false if the transformation definition is an original' do
      expect(original.copy?).to be false
    end
  end

  describe 'kinds' do
    let(:harvest_transformation_definition) { create(:transformation_definition, kind: :harvest) }
    let(:enrichment_transformation_definition) { create(:transformation_definition, kind: :enrichment) }

    it 'can be for a harvest' do
      expect(harvest_transformation_definition.harvest?).to be true
    end

    it 'can be for an enrichment' do
      expect(enrichment_transformation_definition.enrichment?).to be true
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(subject.name).to eq "national-library-of-new-zealand__harvest-transformation-#{subject.id}"
    end
  end
end
