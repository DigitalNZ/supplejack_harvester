# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pipeline do
  describe 'validations' do
    subject { build(:pipeline) }

    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
    let(:pipeline) { create(:pipeline) }
    let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
    let!(:enrichment_definition_one) { create(:harvest_definition, :enrichment, pipeline:) }
    let!(:enrichment_definition_two) { create(:harvest_definition, :enrichment, pipeline:) }

    it 'has_one harvest' do
      expect(pipeline.harvest).to eq harvest_definition
    end

    it 'has_many enrichments' do
      expect(pipeline.enrichments).to eq [enrichment_definition_one, enrichment_definition_two]
    end
  end

  describe '#ready_to_run?' do
    it 'returns false if there is no harvest' do
      pipeline = create(:pipeline)
      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns false if the harvest has no extraction_definition' do
      pipeline = create(:pipeline)
      create(:harvest_definition, pipeline:, extraction_definition: nil)

      pipeline.reload

      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns false if the harvest has no transformation_definition' do
      pipeline = create(:pipeline)
      create(:harvest_definition, pipeline:, transformation_definition: nil)

      pipeline.reload

      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns false if the harvest transformation_definition has no fields' do
      pipeline = create(:pipeline)
      create(:harvest_definition, pipeline:)

      pipeline.reload

      expect(pipeline.harvest.transformation_definition.fields).to be_empty
      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns true if the pipeline is ready to run' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline:)
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                     transformation_definition: harvest_definition.transformation_definition)

      expect(pipeline.ready_to_run?).to be(true)
    end
  end
end
