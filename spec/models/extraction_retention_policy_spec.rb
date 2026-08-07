# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionRetentionPolicy do
  let(:config) do
    {
      dry_run: false,
      batch_limit: 50,
      min_age_months: 1,
      keep_latest: 24,
      max_age_months: 6,
      excluded_extraction_definition_ids: [7]
    }
  end

  subject(:policy) { described_class.new(config) }

  describe '.load' do
    it 'reads the numbers from config/retention.yml' do
      loaded = described_class.load

      expect(loaded.keep_latest).to eq 24
      expect(loaded.min_age_months).to eq 1
      expect(loaded.max_age_months).to eq 6
    end

    it 'ships with dry_run switched on' do
      expect(described_class.load.dry_run?).to be true
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

  describe '#excluded_extraction_definition_ids' do
    it 'exposes the escape hatch list' do
      expect(policy.excluded_extraction_definition_ids).to eq [7]
    end

    it 'defaults to empty when the key is absent' do
      expect(described_class.new(config.except(:excluded_extraction_definition_ids))
                            .excluded_extraction_definition_ids).to eq []
    end
  end
end
