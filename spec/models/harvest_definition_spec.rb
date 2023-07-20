# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestDefinition, type: :model do
  subject do
    create(
      :harvest_definition,
      pipeline:,
      source_id: 'test',
      extraction_definition:,
      transformation_definition:
    )
  end

  let(:pipeline)                    { create(:pipeline, name: 'National Library of New Zealand') }
  let(:harvest_definition)          { create(:harvest_definition, pipeline:, extraction_definition:, transformation_definition:) }
  let(:extraction_definition)       { create(:extraction_definition) }
  let(:extraction_job)              { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition)   { create(:transformation_definition, extraction_job:) }

  describe '#attributes' do
    it 'belongs to a pipeline' do
      expect(subject.pipeline).to eq pipeline
    end

    it 'has an extraction definition' do
      expect(subject.extraction_definition).to eq extraction_definition
    end

    it 'has a transformation definition' do
      expect(subject.transformation_definition).to eq transformation_definition
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(subject.name).to eq "national-library-of-new-zealand__harvest-#{subject.id}"
    end
  end

  describe '#kinds' do
    it 'can be for a harvest' do
      subject.update(kind: :harvest)
      subject.reload
      expect(subject.harvest?).to be true
    end

    it 'can be for an enrichment' do
      subject.update(kind: :enrichment)
      subject.reload
      expect(subject.enrichment?).to be true
    end
  end
end
