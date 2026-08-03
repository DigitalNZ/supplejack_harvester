# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RunSettings do
  describe 'normalization' do
    subject(:settings) do
      described_class.new({ 12 => { 'run' => '1', 'input' => 'preprocess_output:44' },
                            '13' => { run: '0', input: 'garbage' } })
    end

    it 'coerces params into booleans, string keys and canonical inputs' do
      expect(settings.to_h).to eq(
        '12' => { 'run' => true, 'input' => 'preprocess_output:44' },
        '13' => { 'run' => false, 'input' => 'fresh' }
      )
    end

    it 'answers run? and input_for by definition id' do
      expect(settings.run?(12)).to be true
      expect(settings.run?('13')).to be false
      expect(settings.input_for(12).pipeline_job_id).to eq 44
    end

    it 'treats blocks it has never heard of as not running, on a fresh input' do
      expect(settings.run?(999)).to be false
      expect(settings.input_for(999)).to be_fresh
    end

    it 'lists the definition ids to run' do
      expect(settings.definition_ids_to_run).to eq ['12']
    end
  end

  describe '.legacy' do
    it 'reads the flat fields as per-block settings' do
      settings = described_class.legacy(definitions_to_run: %w[12 13], extraction_job_id: 987,
                                        non_enrichment_ids: [12])

      expect(settings.run?(12)).to be true
      expect(settings.run?(13)).to be true
      expect(settings.input_for(12).extraction_job_id).to eq 987
    end

    # extraction_job_id was only ever consumed for non-enrichment blocks
    # (HarvestWorker), so an enrichment must not inherit it.
    it 'leaves enrichment blocks on a fresh input' do
      settings = described_class.legacy(definitions_to_run: %w[12 13], extraction_job_id: 987,
                                        non_enrichment_ids: [12])

      expect(settings.input_for(13)).to be_fresh
    end

    it 'is empty when nothing was requested' do
      expect(described_class.legacy(definitions_to_run: [''])).to be_empty
    end
  end

  describe '.default_for' do
    let(:pipeline)               { create(:pipeline) }
    let(:transformation_definition) { create(:transformation_definition, pipeline:) }
    let!(:field)                 { create(:field, transformation_definition:) }
    let!(:ready)                 { create(:harvest_definition, pipeline:, transformation_definition:) }
    let!(:not_ready)             { create(:harvest_definition, pipeline:, extraction_definition: nil) }

    it 'runs every block that is ready to run, on its default input' do
      settings = described_class.default_for(pipeline)

      expect(settings.run?(ready.id)).to be true
      expect(settings.run?(not_ready.id)).to be false
      expect(settings.input_for(ready.id)).to be_fresh
    end
  end
end
