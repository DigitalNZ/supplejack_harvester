# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationTemplatesHelper do
  describe '#find_harvest_report' do
    let(:pipeline) { create(:pipeline) }
    let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
    let(:position) { 0 }
    
    context 'when automation run is nil' do
      it 'returns nil' do
        expect(helper.find_harvest_report(nil, harvest_definition, position)).to be_nil
      end
    end
    
    context 'when automation run exists but no matching report is found' do
      let(:automation_run) { create(:automation) }
      
      it 'returns nil' do
        expect(helper.find_harvest_report(automation_run, harvest_definition, position)).to be_nil
      end
    end
    
    context 'when a matching report is found' do
      let(:automation_run) { create(:automation) }
      let(:automation_step) { create(:automation_step, automation: automation_run, position: position) }
      let(:pipeline_job) { create(:pipeline_job, automation_step: automation_step) }
      let(:harvest_job) { create(:harvest_job, harvest_definition: harvest_definition) }
      let(:harvest_report) { create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job) }
      
      before do
        # Ensure objects are created in the right order
        pipeline
        harvest_definition
        automation_run
        automation_step
        pipeline_job
        harvest_job
        harvest_report
      end
      
      it 'returns the harvest report' do
        expect(helper.find_harvest_report(automation_run, harvest_definition, position)).to eq(harvest_report)
      end
    end
  end
end
