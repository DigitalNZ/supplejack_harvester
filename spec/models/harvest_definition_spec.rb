# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestDefinition, type: :model do
  subject do
    create(
      :harvest_definition,
      content_source:,
      extraction_definition:,
      transformation_definition:,
      destination:,
      source_id: 'test'
    )
  end

  let(:content_source) { create(:content_source, :ngataonga, name: 'National Library of New Zealand') }
  let(:extraction_definition) { content_source.extraction_definitions.first }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition) { create(:transformation_definition, content_source:, extraction_job:) }
  let(:destination) { create(:destination) }

  describe '#attributes' do
    it 'belongs to a content source' do
      expect(subject.content_source).to eq content_source
    end

    it 'has a copy of the provided extraction definition' do
      expect(subject.extraction_definition.original_extraction_definition).to eq extraction_definition
    end

    it 'has a transformation definition' do
      expect(subject.transformation_definition.original_transformation_definition).to eq transformation_definition
    end

    it 'has a destination' do
      expect(subject.destination).to eq destination
    end
  end

  describe '#clone_transformation_definition' do
    let(:field) { build(:field) }
    let!(:transformation_definition) { create(:transformation_definition, fields: [field]) }

    it 'creates a safe copy of the provided transformation definition' do
      expect do
        described_class.new(transformation_definition:).clone_transformation_definition
      end.to change(TransformationDefinition, :count).by(1)
    end

    it 'creates a copy of the transformation definition that has the same fields' do
      described_class.new(transformation_definition:).clone_transformation_definition

      expect(transformation_definition.copies.count).to eq 1
      copy = transformation_definition.copies.first
      expect(copy.original_transformation_definition).to eq transformation_definition

      transformation_definition.fields.zip(copy.fields) do |transformation_definition_field, copy_field|
        expect(copy_field.name).to eq transformation_definition_field.name
        expect(copy_field.block).to eq transformation_definition_field.block
      end
    end
  end

  describe '#update_transformation_definition_clone' do
    let(:field) { build(:field) }
    let(:transformation_definition) do
      create(:transformation_definition, content_source:, extraction_job:, fields: [field])
    end

    let(:updated_field) { build(:field, name: 'test') }
    let(:updated_transformation_definition) do
      create(:transformation_definition, content_source:, extraction_job:, name: 'updated',
                                         record_selector: 'updated record selector', fields: [updated_field])
    end
    let(:harvest_job) { create(:harvest_job, harvest_definition: subject) }

    it 'updates the safe transformation definition copy to have the new fields and record_selector' do
      subject
      copy = transformation_definition.copies.first
      expect(subject.transformation_definition).to eq transformation_definition.copies.first
      subject.update_transformation_definition_clone(updated_transformation_definition)

      subject.reload

      expect(subject.transformation_definition.record_selector).to eq 'updated record selector'
      expect(subject.transformation_definition.fields.first.name).to eq 'test'
    end

    it 'maintains the relationship between the copied transformation definition and anything else that references it' do
      subject
      copy = transformation_definition.copies.first
      expect(subject.transformation_definition).to eq transformation_definition.copies.first
      subject.update_transformation_definition_clone(updated_transformation_definition)

      subject.reload

      expect(subject.transformation_definition.id).to eq copy.id
    end
  end

  describe '#clone_extraction_definition' do
    let!(:extraction_definition) { create(:extraction_definition) }

    it 'creates a safe copy of the extraction_definition' do
      expect do
        described_class.new(extraction_definition:).clone_extraction_definition
      end.to change(ExtractionDefinition, :count).by(1)
    end

    it 'creates a safe copy of the extraction definition that has the same information' do
      described_class.new(extraction_definition:).clone_extraction_definition

      expect(extraction_definition.copies.count).to eq 1
      copy = extraction_definition.copies.first
      expect(copy.original_extraction_definition).to eq extraction_definition
    end
  end

  describe '#update_extraction_definition_clone' do
    let!(:extraction_definition) { create(:extraction_definition) }
    let!(:updated_extraction_definition) { create(:extraction_definition, base_url: 'http://www.test.co.nz') }

    it 'updates the extraction_definition clone to have the same values as the provided extracted_definition' do
      subject
      copy = extraction_definition.copies.first
      expect(subject.extraction_definition).to eq extraction_definition.copies.first
      subject.update_extraction_definition_clone(updated_extraction_definition)

      subject.reload

      expect(subject.extraction_definition.base_url).to eq 'http://www.test.co.nz'
    end

    it 'maintains the relationship between the extraction_definition and anything else that references it' do
      subject
      copy = extraction_definition.copies.first
      expect(subject.extraction_definition).to eq extraction_definition.copies.first
      subject.update_extraction_definition_clone(updated_extraction_definition)

      subject.reload

      expect(subject.extraction_definition.id).to eq copy.id
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(subject.name).to eq "national-library-of-new-zealand__harvest-#{subject.id}"
    end
  end

  describe 'safe_copy' do
    let(:content_source)           { create(:content_source, :ngataonga) }
    let(:extraction_definition)     { content_source.extraction_definitions.first }
    let(:transformation_definition) { create(:transformation_definition, content_source:, extraction_job:) }
    let(:destination)               { create(:destination) }

    it 'creates a safe copy of the extraction_definition' do
      hd = described_class.new(content_source:, extraction_definition:, transformation_definition:, destination:,
                               source_id: 'test')
      hd.save!

      hd.reload

      expect(hd.extraction_definition.original_extraction_definition).to eq extraction_definition
    end

    it 'creates a safe copy of the transformation_definition' do
      hd = described_class.new(content_source:, extraction_definition:, transformation_definition:, destination:,
                               source_id: 'test')
      hd.save!

      hd.reload

      expect(hd.transformation_definition.original_transformation_definition).to eq transformation_definition
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

  describe '#extraction_definition_is_a_copy' do
    it 'does not allow being associated with an original extraction definition' do
      subject.extraction_definition = extraction_definition
      expect(subject).not_to be_valid
    end
  end


  describe '#transformation_definition_is_a_copy' do
    it 'does not allow being associated with an original transformation definition' do
      subject.transformation_definition = transformation_definition
      expect(subject).not_to be_valid
    end
  end
end
