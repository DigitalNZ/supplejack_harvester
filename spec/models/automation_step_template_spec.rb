# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationStepTemplate do
  subject { create(:automation_step_template) }

  it { is_expected.to belong_to(:automation_template) }
  it { is_expected.to belong_to(:pipeline).optional }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

  context 'when step_type is pipeline' do
    subject { build(:automation_step_template, step_type: 'pipeline') }
    
    it { is_expected.to validate_presence_of(:pipeline_id) }
  end

  context 'when step_type is api_call' do
    subject { build(:automation_step_template, step_type: 'api_call') }
    
    it { is_expected.to validate_presence_of(:api_url) }
    it { is_expected.to validate_presence_of(:api_method) }
  end

  context 'when step_type is independent_extraction' do
    let(:extraction_definition) { create(:extraction_definition, independent_extraction: true) }
    subject { build(:automation_step_template, step_type: 'independent_extraction', extraction_definition:, pipeline: nil) }
    
    it { is_expected.to validate_presence_of(:extraction_definition_id) }
  end

  describe '#update_position' do
    it 'updates the position attribute' do
      new_position = subject.position + 1
      expect { subject.update_position(new_position) }.to change { subject.position }.to(new_position)
    end
  end

  describe '#harvest_definitions' do
    it 'returns harvest definitions from IDs' do
      pipeline = subject.pipeline
      harvest_definition = create(:harvest_definition, pipeline: pipeline)
      
      subject.harvest_definition_ids = [harvest_definition.id]
      subject.save

      expect(subject.harvest_definitions).to include(harvest_definition)
    end

    it 'returns empty array when pipeline is nil' do
      template = build(:automation_step_template, pipeline: nil)
      expect(template.harvest_definitions).to eq([])
    end

    it 'returns all harvest definitions when harvest_definition_ids is blank' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline: pipeline)
      template = create(:automation_step_template, pipeline: pipeline, harvest_definition_ids: [])
      
      expect(template.harvest_definitions).to include(harvest_definition)
    end
  end

  describe '#display_name' do
    it 'returns a formatted name with position and pipeline name for pipeline step' do
      template = create(:automation_step_template, step_type: 'pipeline')
      expect(template.display_name).to eq("#{template.position + 1}. #{template.pipeline.name}")
    end

    it 'returns a formatted name with API method and URL for api_call step' do
      template = create(:automation_step_template, 
                      step_type: 'api_call', 
                      api_method: 'GET', 
                      api_url: 'https://example.com/api')
      expect(template.display_name).to eq("#{template.position + 1}. API Call: GET https://example.com/api")
    end

    it 'returns a formatted name with extraction definition name for independent_extraction step' do
      extraction_definition = create(:extraction_definition, independent_extraction: true)
      template = create(:automation_step_template, :independent_extraction, extraction_definition:)
      expect(template.display_name).to include('Independent Extraction')
      expect(template.display_name).to include(extraction_definition.name)
    end
  end
end 
