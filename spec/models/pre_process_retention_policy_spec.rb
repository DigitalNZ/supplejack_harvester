# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreProcessRetentionPolicy do
  let(:config) do
    {
      dry_run: false,
      keep_latest: 4
    }
  end

  subject(:policy) { described_class.new(config) }

  describe '.load' do
    it 'reads the preprocess section of config/retention.yml' do
      expect(described_class.load.keep_latest).to eq 4
    end

    it 'ships armed - dry_run is off' do
      expect(described_class.load.dry_run?).to be false
    end

    it 'has no age cutoffs - a leftover age key would change nothing here' do
      loaded = described_class.load

      expect(loaded.respond_to?(:min_age_cutoff)).to be false
      expect(loaded.respond_to?(:max_age_cutoff)).to be false
    end
  end

  describe '#dry_run?' do
    it 'reflects the configured flag' do
      expect(policy.dry_run?).to be false
    end
  end

  it 'fails loudly when a key is missing' do
    expect { described_class.new(dry_run: true) }.to raise_error(KeyError)
  end
end
