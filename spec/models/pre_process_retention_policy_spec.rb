# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreProcessRetentionPolicy do
  let(:config) do
    {
      dry_run: false,
      min_age_months: 1,
      max_age_months: 6
    }
  end

  subject(:policy) { described_class.new(config) }

  describe '.load' do
    it 'reads the preprocess section of config/retention.yml' do
      loaded = described_class.load

      expect(loaded.min_age_months).to eq 1
      expect(loaded.max_age_months).to eq 6
    end

    it 'ships with dry_run switched on' do
      expect(described_class.load.dry_run?).to be true
    end

    it 'is independent of the extraction section' do
      expect(described_class.load.respond_to?(:keep_latest)).to be false
    end
  end

  describe '#min_age_cutoff' do
    it 'is min_age_months before now' do
      expect(policy.min_age_cutoff).to be_within(1.second).of(1.month.ago)
    end
  end

  describe '#max_age_cutoff' do
    it 'is max_age_months before now' do
      expect(policy.max_age_cutoff).to be_within(1.second).of(6.months.ago)
    end
  end

  describe '#dry_run?' do
    it 'reflects the configured flag' do
      expect(policy.dry_run?).to be false
    end
  end
end
