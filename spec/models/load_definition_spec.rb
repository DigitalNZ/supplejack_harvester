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
    # Both kinds that say they write a secondary fragment have to mean it: at 0 the API selects
    # the primary fragment and nils every mutable field the payload does not carry.
    %w[secondary_fragment enrichment].each do |kind|
      it "refuses a #{kind.humanize.downcase} at 0, which would write the primary fragment instead" do
        load_definition = described_class.new(pipeline:, kind:, priority: 0)

        expect(load_definition).not_to be_valid
        expect(load_definition.errors[:priority].join).to include 'must not be 0'
      end

      it "accepts a #{kind.humanize.downcase} at a non-zero priority" do
        expect(described_class.new(pipeline:, kind:, priority: -1)).to be_valid
      end
    end

    it 'refuses the primary fragment at a non-zero priority' do
      load_definition = described_class.new(pipeline:, kind: 'primary_fragment', priority: -1)

      expect(load_definition).not_to be_valid
      expect(load_definition.errors[:priority].join).to include 'must be 0 to write the primary fragment'
    end

    # A block writing to disk posts nothing, so there is no fragment for a priority to pick.
    it 'leaves a preprocessing load alone, which writes no fragment at all' do
      expect(described_class.new(pipeline:, kind: 'preprocessed_data', priority: 0)).to be_valid
      expect(described_class.new(pipeline:, kind: 'preprocessed_data', priority: -2)).to be_valid
    end

    it 'refuses a blank priority rather than failing on the database constraint' do
      expect(described_class.new(pipeline:, kind: 'primary_fragment', priority: nil)).not_to be_valid
    end
  end

  # The block validates the pairing as it picks a definition up; this is the other direction,
  # editing a definition to something the blocks already using it cannot do.
  describe '#kind, against the blocks loading through it' do
    let(:load_definition) { create(:load_definition, pipeline:) }

    it 'cannot become a kind its block does not do' do
      create(:harvest_definition, pipeline:, kind: :harvest, source_id: 'a-harvest', load_definition:)

      load_definition.kind = 'preprocessed_data'

      expect(load_definition).not_to be_valid
      expect(load_definition.errors[:kind].join).to eq 'is not something the harvest block a-harvest can do'
    end

    it 'names every block that cannot follow it' do
      create(:harvest_definition, pipeline:, kind: :harvest, source_id: 'one', load_definition:)
      create(:harvest_definition, pipeline: create(:pipeline), kind: :harvest, source_id: 'two', load_definition:)

      load_definition.kind = 'enrichment'
      load_definition.valid?

      expect(load_definition.errors[:kind].join)
        .to eq 'is not something the harvest block one and the harvest block two can do'
    end

    it 'can still move between the kinds its block does do' do
      create(:harvest_definition, pipeline:, kind: :harvest, source_id: 'a-harvest', load_definition:)

      expect(load_definition.update(kind: 'secondary_fragment', priority: -1)).to be true
    end

    it 'is free to be any kind while no block uses it' do
      expect(load_definition.update(kind: 'preprocessed_data')).to be true
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

  describe 'request settings' do
    it 'accepts the offered timeouts' do
      LoadDefinition::READ_TIMEOUT_OPTIONS.each_key do |seconds|
        expect(build(:load_definition, pipeline:, read_timeout: seconds)).to be_valid
      end
    end

    describe '.read_timeout_options' do
      it 'names the choices in plain English rather than in seconds' do
        expect(described_class.read_timeout_options).to include(['2 minutes', 120])
      end

      # Every entry is a wait: there is no entry standing for a default the form does not name,
      # which is what the helper text is for.
      it 'offers the waits and nothing else' do
        expect(described_class.read_timeout_options.map(&:last)).to eq [30, 60, 120, 180]
      end
    end

    it 'names the wait a definition starts on for the helper text to quote' do
      expect(described_class.default_read_timeout_label).to eq '1 minute'
    end

    # A minute is what every load waited before the column existed, so a definition that says
    # nothing about it keeps waiting exactly that.
    it 'starts on a minute' do
      expect(create(:load_definition, pipeline:).read_timeout).to eq LoadDefinition::DEFAULT_READ_TIMEOUT
    end

    it 'refuses a timeout that is not one of the offered choices' do
      expect(build(:load_definition, pipeline:, read_timeout: 45)).not_to be_valid
    end

    # The column is not nullable, so nothing can ask for the wait to be left unsaid.
    it 'refuses a definition with no timeout at all' do
      expect(build(:load_definition, pipeline:, read_timeout: nil)).not_to be_valid
    end

    it 'refuses a batch that would slice into nothing' do
      expect(build(:load_definition, pipeline:, batch_size: 0)).not_to be_valid
    end

    it 'refuses a batch larger than the destination has ever been asked for' do
      expect(build(:load_definition, pipeline:, batch_size: 101)).not_to be_valid
    end

    it 'defaults to the size LoadWorker has always sliced at' do
      expect(create(:load_definition, pipeline:).batch_size).to eq LoadDefinition::DEFAULT_BATCH_SIZE
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
