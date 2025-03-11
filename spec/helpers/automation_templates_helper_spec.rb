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
  
  describe '#harvest_report_status' do
    context 'when report is nil' do
      it 'returns default status' do
        status = helper.harvest_report_status(nil)
        expect(status[:badge_class]).to eq('bg-secondary')
        expect(status[:status_text]).to eq('Not started')
      end
    end
    
    context 'when report exists' do
      let(:report) { instance_double('HarvestReport', status: 'completed') }
      
      before do
        allow(helper).to receive(:status_badge_class).with('completed').and_return('bg-success')
      end
      
      it 'returns status based on the report' do
        status = helper.harvest_report_status(report)
        expect(status[:badge_class]).to eq('bg-success')
        expect(status[:status_text]).to eq('Completed')
      end
    end
  end
end 