# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pipeline do
  describe 'validations' do
    subject { build(:pipeline) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.with_message('has already been taken') }
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
    
    it 'has_many automation_step_templates' do
      expect(pipeline).to respond_to(:automation_step_templates)
    end
    
    it 'has_many automation_templates through automation_step_templates' do
      expect(pipeline).to respond_to(:automation_templates)
      
      other_pipeline = create(:pipeline)
      automation_template = create(:automation_template)
      other_template = create(:automation_template)
      
      create(:automation_step_template, pipeline: pipeline, automation_template: automation_template)
      create(:automation_step_template, pipeline: other_pipeline, automation_template: other_template)
      # Add pipeline to another template to test distinct
      create(:automation_step_template, pipeline: pipeline, automation_template: automation_template, position: 1)
      
      expect(pipeline.automation_templates).to include(automation_template)
      expect(pipeline.automation_templates).not_to include(other_template)
      # Even though pipeline is in automation_template twice, it should only be returned once
      expect(pipeline.automation_templates.count).to eq(1)
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

  describe 'block ordering' do
    let(:pipeline) { create(:pipeline) }
    let!(:harvest)  { create(:harvest_definition, pipeline:, kind: :harvest,    position: 2) }
    let!(:pre_zero) { create(:harvest_definition, pipeline:, kind: :preprocess, position: 0) }
    let!(:pre_one)  { create(:harvest_definition, pipeline:, kind: :preprocess, position: 1) }

    it 'returns preprocess blocks in position order' do
      expect(pipeline.preprocesses.to_a).to eq([pre_zero, pre_one])
    end

    it 'returns the chain in position order' do
      expect(pipeline.ordered_blocks.to_a).to eq([pre_zero, pre_one, harvest])
    end

    it 'excludes enrichment definitions from the chain' do
      enrichment = create(:harvest_definition, pipeline:, kind: :enrichment, position: 0)

      expect(pipeline.ordered_blocks).not_to include(enrichment)
      expect(pipeline.ordered_blocks.to_a).to eq([pre_zero, pre_one, harvest])
    end
  end
end
