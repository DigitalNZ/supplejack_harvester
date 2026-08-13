# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadDefinition do
  let(:pipeline) { create(:pipeline, name: 'National Library of New Zealand') }

  describe '#kind' do
    it 'defaults to writing the primary fragment' do
      expect(described_class.create(pipeline:)).to be_primary_fragment
    end

    it 'can write a secondary fragment instead' do
      expect(described_class.create(pipeline:, kind: 'secondary_fragment', priority: -1)).to be_secondary_fragment
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      load_definition = described_class.create(pipeline:, kind: 'secondary_fragment', priority: -1)

      expect(load_definition.name).to eq "#{load_definition.id}_secondary_fragment-load"
    end

    it 'keeps a name it was given' do
      expect(described_class.create(pipeline:, name: 'tag CEISMIC').name).to eq 'tag CEISMIC'
    end

    it 'must be unique' do
      described_class.create(pipeline:, name: 'tag CEISMIC')

      expect(described_class.create(pipeline:, name: 'tag CEISMIC')).not_to be_valid
    end
  end

  describe '#priority' do
    it 'refuses a secondary fragment at 0, which would write the primary fragment instead' do
      load_definition = described_class.new(pipeline:, kind: 'secondary_fragment', priority: 0)

      expect(load_definition).not_to be_valid
      expect(load_definition.errors[:priority].join).to include 'must not be 0 for a secondary fragment'
    end

    it 'accepts a secondary fragment at a non-zero priority' do
      expect(described_class.new(pipeline:, kind: 'secondary_fragment', priority: -1)).to be_valid
    end

    it 'refuses the primary fragment at a non-zero priority' do
      load_definition = described_class.new(pipeline:, kind: 'primary_fragment', priority: -1)

      expect(load_definition).not_to be_valid
      expect(load_definition.errors[:priority].join).to include 'must be 0 to write the primary fragment'
    end

    it 'leaves an enrichment free to write either fragment' do
      expect(described_class.new(pipeline:, kind: 'enrichment', priority: 0)).to be_valid
      expect(described_class.new(pipeline:, kind: 'enrichment', priority: -2)).to be_valid
    end

    it 'refuses a blank priority rather than failing on the database constraint' do
      expect(described_class.new(pipeline:, kind: 'primary_fragment', priority: nil)).not_to be_valid
    end
  end

  describe '#shared?' do
    let(:load_definition) { create(:load_definition, pipeline:) }

    it 'is not shared when only one block loads through it' do
      create(:harvest_definition, pipeline:, load_definition:)

      expect(load_definition).not_to be_shared
    end

    it 'is shared when more than one block loads through it' do
      create(:harvest_definition, pipeline:, load_definition:)
      create(:harvest_definition, pipeline:, load_definition:)

      expect(load_definition).to be_shared
    end
  end

  describe '#clone' do
    it 'copies the settings onto a new definition in the given pipeline' do
      load_definition = create(:load_definition, pipeline:, kind: 'secondary_fragment', priority: -1)
      other_pipeline  = create(:pipeline, name: 'Auckland Libraries')

      clone = load_definition.clone(other_pipeline, 'cloned')

      expect(clone).to have_attributes(
        name: 'cloned', pipeline: other_pipeline, kind: 'secondary_fragment', priority: -1
      )
    end
  end
end
