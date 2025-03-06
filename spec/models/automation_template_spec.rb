# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationTemplate do
  subject { create(:automation_template) }

  it { is_expected.to belong_to(:destination) }
  it { is_expected.to have_many(:automation_step_templates).dependent(:destroy) }
  it { is_expected.to have_many(:automations) }
  it { is_expected.to validate_presence_of(:name) }

  describe '#run_automation' do
    let(:user) { create(:user) }
    let(:pipeline) { create(:pipeline) }

    context 'with step templates' do
      before do
        create(:automation_step_template, automation_template: subject, position: 0, pipeline: pipeline)
      end

      it 'creates a new automation' do
        expect {
          subject.run_automation(user)
        }.to change(Automation, :count).by(1)
      end

      it 'creates automation steps from templates' do
        # Create a template with a unique name
        template = build(:automation_template)
        template.name = "Template #{SecureRandom.hex(8)}"
        template.save!
        
        create(:automation_step_template, automation_template: template, position: 0, pipeline: pipeline)
        create(:automation_step_template, automation_template: template, position: 1, pipeline: pipeline)

        automation, _, _ = template.run_automation(user)

        expect(automation.automation_steps.count).to eq(2)
      end

      it 'returns the created automation and success message' do
        automation, message, success = subject.run_automation(user)

        expect(automation).to be_a(Automation)
        expect(message).to include('successfully')
        expect(success).to be true
      end
    end

    context 'without step templates' do
      it 'creates an automation but returns no success message' do
        automation, message, success = subject.run_automation(user)
        
        expect(automation).to be_a(Automation)
        expect(message).to include("couldn't be started")
        expect(success).to be false
      end
    end
  end
end 