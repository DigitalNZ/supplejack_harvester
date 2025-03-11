# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationStepTemplate do
  subject { create(:automation_step_template) }

  it { is_expected.to belong_to(:automation_template) }
  it { is_expected.to belong_to(:pipeline) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

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
  end

  describe '#display_name' do
    it 'returns a formatted name with position and pipeline name' do
      expect(subject.display_name).to eq("#{subject.position + 1}. #{subject.pipeline.name}")
    end
  end
end 