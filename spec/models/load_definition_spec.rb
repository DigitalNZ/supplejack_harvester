# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadDefinition do
  let(:pipeline) { create(:pipeline, name: 'National Library of New Zealand') }

  describe '#kind' do
    it 'defaults to writing the primary fragment' do
      expect(described_class.create(pipeline:)).to be_primary_fragment
    end

    it 'can write a secondary fragment instead' do
      expect(described_class.create(pipeline:, kind: 'secondary_fragment')).to be_secondary_fragment
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      load_definition = described_class.create(pipeline:, kind: 'secondary_fragment')

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
