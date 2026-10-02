# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationWorker, type: :job do
  let(:automation_template) { create(:automation_template) }
  let(:automation) { create(:automation, automation_template: automation_template) }
  
  describe "#perform" do
    context "when the automation does not exist" do
      it "does not process the step" do

        worker = described_class.new

        expect(worker).not_to receive(:process_step)
        
        worker.perform(1231, 2000)
      end
    end
    
    context "when the step does not exist" do
      it "does not process the step" do

        worker = described_class.new

        expect(worker).not_to receive(:process_step)
        
        worker.perform(automation.id, 2000)
      end
    end
  end
end
