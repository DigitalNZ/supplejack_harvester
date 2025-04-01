# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Automation do
  let(:automation_template) { create(:automation_template) }
  let(:pipeline) { create(:pipeline) }
  subject { create(:automation, automation_template: automation_template) }
  let(:user) { create(:user) }

  it { is_expected.to belong_to(:destination) }
  it { is_expected.to belong_to(:automation_template) }
  it { is_expected.to have_many(:automation_steps).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:destination).with_message("must be selected") }
  
  describe '#run' do
    it 'enqueues the automation worker with the first step' do
      step = create(:automation_step, automation: subject, position: 0, launched_by: user, pipeline: pipeline)
      expect(AutomationWorker).to receive(:perform_async).with(subject.id, step.id)
      subject.run
    end
    
    it 'does nothing if there are no steps' do
      expect(AutomationWorker).not_to receive(:perform_async)
      subject.run
    end
  end
  
  describe '#can_run?' do
    it 'returns true if there are steps and status is not_started' do
      create(:automation_step, automation: subject, launched_by: user, pipeline: pipeline)
      allow(subject).to receive(:status).and_return('not_started')
      expect(subject.can_run?).to be true
    end
    
    it 'returns false if there are no steps' do
      allow(subject).to receive(:status).and_return('not_started')
      expect(subject.can_run?).to be false
    end
    
    it 'returns false if status is not not_started' do
      create(:automation_step, automation: subject, launched_by: user, pipeline: pipeline)
      allow(subject).to receive(:status).and_return('running')
      expect(subject.can_run?).to be false
    end
  end
  
  describe '#status' do
    context 'when no steps exist' do
      it 'returns not_started' do
        expect(subject.status).to eq('not_started')
      end
    end
    
    context 'with steps' do
      let(:step) { create(:automation_step, automation: subject, launched_by: user, pipeline: pipeline) }
      let(:pipeline_job) { create(:pipeline_job, automation_step: step, pipeline: pipeline) }
      let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
      let(:extraction_job) { create(:extraction_job) }
      let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }
      
      it 'returns running if any status is running' do
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'running', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed')
        expect(subject.status).to eq('running')
      end
      
      it 'returns completed if all statuses are completed' do
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed')
        expect(subject.status).to eq('completed')
      end
      
      it 'returns failed if any status is errored' do
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'errored', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed')
        expect(subject.status).to eq('errored')
      end
      
      it 'does not return completed if not all steps have reports, even if all existing reports are completed' do
        # Create first step with a completed report
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed')
        
        # Create a second step with no reports (not started yet)
        second_step = create(:automation_step, automation: subject, launched_by: user, pipeline: pipeline, position: 1)
        
        # Status should be running because second step has no pipeline job yet
        expect(subject.status).to eq('running')
      end
      
      it 'does not return completed if some steps have a pipeline job but no reports' do
        # Create first step with a completed report
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
               extraction_status: 'completed', 
               transformation_status: 'completed', 
               load_status: 'completed',
               delete_status: 'completed')
        
        # Create a second step with a pipeline job but no reports
        # Use a dynamic position value to avoid uniqueness constraint violations
        next_position = subject.automation_steps.maximum(:position).to_i + 1
        second_step = create(:automation_step, automation: subject, launched_by: user, pipeline: pipeline, position: next_position)
        create(:pipeline_job, automation_step: second_step, pipeline: pipeline)
        
        # Status should be running because second step has a pipeline job but no reports
        expect(subject.status).to eq('running')
      end
    end
    
    context 'with API call steps' do
      let(:api_step) { create(:automation_step, automation: subject, pipeline: nil, step_type: 'api_call', api_url: 'https://api.example.com', api_method: 'GET') }
      
      it 'returns completed when API call is completed' do
        create(:api_response_report, automation_step: api_step, status: 'completed')
        expect(subject.status).to eq('completed')
      end
      
      it 'returns running when API call is running' do
        create(:api_response_report, automation_step: api_step, status: 'running')
        expect(subject.status).to eq('running')
      end
      
      it 'returns failed when API call is errored' do
        create(:api_response_report, automation_step: api_step, status: 'errored')
        expect(subject.status).to eq('errored')
      end
      
      it 'returns not_started when API call has no response report yet' do
        api_step # Just create the step
        expect(subject.status).to eq('not_started')
      end
      
      context 'with mixed step types' do
        let(:pipeline_step) { create(:automation_step, automation: subject, position: 1, launched_by: user, pipeline: pipeline) }
        let(:pipeline_job) { create(:pipeline_job, automation_step: pipeline_step, pipeline: pipeline) }
        let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
        let(:extraction_job) { create(:extraction_job) }
        let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }
        
        it 'returns completed only when both API and pipeline steps are completed' do
          # Set API step as completed
          create(:api_response_report, automation_step: api_step, status: 'completed')
          
          # Set pipeline step as completed
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                 extraction_status: 'completed', 
                 transformation_status: 'completed', 
                 load_status: 'completed',
                 delete_status: 'completed')
                 
          expect(subject.status).to eq('completed')
        end
        
        it 'returns running if API step is completed but pipeline step is still running' do
          # Set API step as completed
          create(:api_response_report, automation_step: api_step, status: 'completed')
          
          # Set pipeline step as running
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                 extraction_status: 'running', 
                 transformation_status: 'completed', 
                 load_status: 'completed',
                 delete_status: 'completed')
                 
          expect(subject.status).to eq('running')
        end
        
        it 'returns failed if either step fails' do
          # Set API step as completed but pipeline step as errored
          create(:api_response_report, automation_step: api_step, status: 'completed')
          create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job, 
                 extraction_status: 'errored', 
                 transformation_status: 'completed', 
                 load_status: 'completed',
                 delete_status: 'completed')
                 
          expect(subject.status).to eq('errored')
          
          # Update pipeline step to completed but API step to errored
          HarvestReport.where(harvest_job: harvest_job).update_all(extraction_status: 'completed')
          api_step.api_response_report.update(status: 'errored')
          
          expect(subject.reload.status).to eq('errored')
        end
      end
    end
  end
  
  describe '#create_pipeline_job' do
    let(:step) { create(:automation_step, automation: subject, launched_by: user, pipeline: pipeline) }
    
    it 'creates a pipeline job for the step' do
      expect {
        subject.create_pipeline_job(step)
      }.to change(PipelineJob, :count).by(1)
    end
    
    it 'enqueues a pipeline worker' do
      expect(PipelineWorker).to receive(:perform_async)
      subject.create_pipeline_job(step)
    end
    
    it 'uses all harvest definitions if none specified' do
      harvest_definitions = create_list(:harvest_definition, 3, pipeline: step.pipeline)
      step.harvest_definition_ids = []
      job = subject.create_pipeline_job(step)
      expect(job.harvest_definitions_to_run.size).to eq(harvest_definitions.size)
    end
    
    it 'uses the specified harvest definitions' do
      harvest_definitions = create_list(:harvest_definition, 3, pipeline: step.pipeline)
      step.harvest_definition_ids = [harvest_definitions.first.id.to_s]
      job = subject.create_pipeline_job(step)
      expect(job.harvest_definitions_to_run).to eq([harvest_definitions.first.id.to_s])
    end
  end
end 