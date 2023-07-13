require 'rails_helper'

RSpec.describe Pipeline, type: :model do
  describe 'validations' do
    subject { build(:pipeline) }
    
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
   let(:pipeline) { create(:pipeline) }
   let!(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
   let!(:enrichment_definition_one) { create(:harvest_definition, :enrichment, pipeline: pipeline) }
   let!(:enrichment_definition_two) { create(:harvest_definition, :enrichment, pipeline: pipeline) }

    it 'has_one harvest' do
      expect(pipeline.harvest).to eq harvest_definition
    end

    it 'has_many enrichments' do
      expect(pipeline.enrichments).to eq [enrichment_definition_one, enrichment_definition_two]
    end

  end
end
