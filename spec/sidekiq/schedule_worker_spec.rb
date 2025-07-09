# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScheduleWorker, type: :job do
  let(:destination) { create(:destination) }
  let(:pipeline) { create(:pipeline) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:field) { create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                 transformation_definition: harvest_definition.transformation_definition) }

  describe '#perform' do
    context "when scheduling a Pipeline" do
      let(:schedule) { create(:schedule, pipeline:, destination:, harvest_definitions_to_run: [harvest_definition.id]) }

      it "create a Pipeline Job" do
        expect { described_class.new.perform(schedule.id) }.to change(PipelineJob, :count).by(1)
      end
    end

    context "when scheduling a Pipeline with a job priority" do
      let(:schedule) { create(:schedule, pipeline:, destination:, harvest_definitions_to_run: [harvest_definition.id], job_priority: 'high_priority') }

      it "create a Pipeline Job with a job priority" do
        described_class.new.perform(schedule.id)
        expect(PipelineJob.last.job_priority).to eq('high_priority')
      end
    end

    context "when scheduling an Automation Template" do
      let(:automation_template) { create(:automation_template) }
      let(:schedule) { create(:schedule, automation_template:, destination:) }

      it "create a Automation" do
        expect(AutomationTemplate).to receive(:find).with(automation_template.id).and_return(automation_template)
        expect(automation_template).to receive(:run_automation)

        described_class.new.perform(schedule.id)
      end
    end
  end
end