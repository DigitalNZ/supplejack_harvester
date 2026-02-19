# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationTemplate do
  subject { create(:automation_template) }

  it { is_expected.to belong_to(:destination) }
  it { is_expected.to have_many(:automation_step_templates).dependent(:destroy) }
  it { is_expected.to have_many(:automations).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:name) }

  describe 'when destroyed' do
    it 'deletes all associated automations' do
      template = create(:automation_template)
      automation1 = create(:automation, automation_template: template)
      automation2 = create(:automation, automation_template: template)
      
      expect {
        template.destroy
      }.to change { Automation.count }.by(-2)
      
      expect(Automation.exists?(automation1.id)).to be_falsey
      expect(Automation.exists?(automation2.id)).to be_falsey
    end
  end

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

  describe '#automation_running?' do
    let(:template) { create(:automation_template) }
    let(:pipeline) { create(:pipeline) }
    let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }

    context 'when there are no automations' do
      it 'returns false' do
        expect(template.automation_running?).to be false
      end
    end

    context 'automations with pipeline steps' do
      context 'when pipelines are running' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :running,
                 transformation_status: :queued,
                 load_status: :queued,
                 delete_status: :queued)
          
          expect(template.automation_running?).to be true
        end

      end

      context 'when all harvest_reports are completed' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :completed,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
          
          expect(template.automation_running?).to be false
        end
      end

      context 'when all harvest_reports are errored' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :errored,
                 transformation_status: :errored,
                 load_status: :errored,
                 delete_status: :errored)
          
          expect(template.automation_running?).to be false
        end
      end
  
      context 'when all harvest_reports are cancelled' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :cancelled,
                 transformation_status: :cancelled,
                 load_status: :cancelled,
                 delete_status: :cancelled)
          
          expect(template.automation_running?).to be false
        end
      end

      context "when the pipline job has been cancelled" do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline, status: "cancelled")
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :completed,
                 transformation_status: :running,
                 load_status: :running,
                 delete_status: :running)
          
          expect(template.automation_running?).to be false 
        end
      end

      context 'when one status phase is running (extraction)' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :running,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
          
          expect(template.automation_running?).to be true
        end
      end
  
      context 'when one status phase is queued (transformation)' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline)
          pipeline_job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: pipeline_job,
                 harvest_job: harvest_job,
                 extraction_status: :completed,
                 transformation_status: :queued,
                 load_status: :completed,
                 delete_status: :completed)
          
          expect(template.automation_running?).to be true
        end
      end
    end

    describe 'with API call steps' do
      context 'when api_response_report status is queued' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :api_call, automation: automation)
          create(:api_response_report, automation_step: step, status: 'queued')
          
          expect(template.automation_running?).to be true
        end
      end
  
      context 'when api_response_report status is running' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :api_call, automation: automation)
          create(:api_response_report, automation_step: step, status: 'running')
          
          expect(template.automation_running?).to be true
        end
      end
  
      context 'when api_response_report status is completed' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :api_call, automation: automation)
          create(:api_response_report, automation_step: step, status: 'completed')
          
          expect(template.automation_running?).to be false
        end
      end
  
      context 'when api_response_report status is errored' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :api_call, automation: automation)
          create(:api_response_report, automation_step: step, status: 'errored')
          
          expect(template.automation_running?).to be false
        end
      end
  
      context 'when api_response_report status is cancelled' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          step = create(:automation_step, :api_call, automation: automation)
          create(:api_response_report, automation_step: step, status: 'cancelled')
          
          expect(template.automation_running?).to be false
        end
      end
    end
  
    describe 'with multiple automations' do
      context 'when one automation is running and one is completed' do
        it 'returns true' do
          # Completed automation
          completed = create(:automation, automation_template: template)
          completed_step = create(:automation_step, :pipeline, automation: completed, pipeline: pipeline)
          completed_job = create(:pipeline_job, automation_step: completed_step, pipeline: pipeline)
          completed_harvest_job = create(:harvest_job, pipeline_job: completed_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: completed_job,
                 harvest_job: completed_harvest_job,
                 extraction_status: :completed,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
  
          # Running automation
          running = create(:automation, automation_template: template)
          running_step = create(:automation_step, :pipeline, automation: running, pipeline: pipeline)
          running_job = create(:pipeline_job, automation_step: running_step, pipeline: pipeline)
          running_harvest_job = create(:harvest_job, pipeline_job: running_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: running_job,
                 harvest_job: running_harvest_job,
                 extraction_status: :running,
                 transformation_status: :queued,
                 load_status: :queued,
                 delete_status: :queued)
          
          expect(template.automation_running?).to be true
        end
      end
  
      context 'when all automations are in completed states' do
        it 'returns false' do
          # Completed automation
          completed = create(:automation, automation_template: template)
          completed_step = create(:automation_step, :pipeline, automation: completed, pipeline: pipeline)
          completed_job = create(:pipeline_job, automation_step: completed_step, pipeline: pipeline)
          completed_harvest_job = create(:harvest_job, pipeline_job: completed_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: completed_job,
                 harvest_job: completed_harvest_job,
                 extraction_status: :completed,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
  
          # Errored automation
          errored = create(:automation, automation_template: template)
          errored_step = create(:automation_step, :pipeline, automation: errored, pipeline: pipeline)
          errored_job = create(:pipeline_job, automation_step: errored_step, pipeline: pipeline)
          errored_harvest_job = create(:harvest_job, pipeline_job: errored_job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: errored_job,
                 harvest_job: errored_harvest_job,
                 extraction_status: :errored,
                 transformation_status: :errored,
                 load_status: :errored,
                 delete_status: :errored)
          
          expect(template.automation_running?).to be false
        end
      end
    end
  
    describe 'with multiple steps in one automation' do
      context 'when first step is completed and second is running' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          
          # First step - completed
          step1 = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline, position: 0)
          job1 = create(:pipeline_job, automation_step: step1, pipeline: pipeline)
          harvest_job1 = create(:harvest_job, pipeline_job: job1, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: job1,
                 harvest_job: harvest_job1,
                 extraction_status: :completed,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
          
          # Second step - running
          step2 = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline, position: 1)
          job2 = create(:pipeline_job, automation_step: step2, pipeline: pipeline)
          harvest_job2 = create(:harvest_job, pipeline_job: job2, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: job2,
                 harvest_job: harvest_job2,
                 extraction_status: :running,
                 transformation_status: :queued,
                 load_status: :queued,
                 delete_status: :queued)
          
          expect(template.automation_running?).to be true
        end
      end
  
      context 'when all steps are completed' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          
          2.times do |i|
            step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline, position: i)
            job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
            harvest_job = create(:harvest_job, pipeline_job: job, harvest_definition: harvest_definition)
            create(:harvest_report,
                   pipeline_job: job,
                   harvest_job: harvest_job,
                   extraction_status: :completed,
                   transformation_status: :completed,
                   load_status: :completed,
                   delete_status: :completed)
          end
          
          expect(template.automation_running?).to be false
        end
      end
    end
  
    describe 'with mixed step types' do
      context 'when pipeline step is completed and API step is running' do
        it 'returns true' do
          automation = create(:automation, automation_template: template)
          
          # Pipeline step - completed
          pipeline_step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline, position: 0)
          job = create(:pipeline_job, automation_step: pipeline_step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: job,
                 harvest_job: harvest_job,
                 extraction_status: :completed,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
          
          # API step - running
          api_step = create(:automation_step, :api_call, automation: automation, position: 1)
          create(:api_response_report, automation_step: api_step, status: 'running')
          
          expect(template.automation_running?).to be true
        end
      end
  
      context 'when both step types are completed' do
        it 'returns false' do
          automation = create(:automation, automation_template: template)
          
          # Pipeline step
          pipeline_step = create(:automation_step, :pipeline, automation: automation, pipeline: pipeline, position: 0)
          job = create(:pipeline_job, automation_step: pipeline_step, pipeline: pipeline)
          harvest_job = create(:harvest_job, pipeline_job: job, harvest_definition: harvest_definition)
          create(:harvest_report,
                 pipeline_job: job,
                 harvest_job: harvest_job,
                 extraction_status: :completed,
                 transformation_status: :completed,
                 load_status: :completed,
                 delete_status: :completed)
          
          # API step
          api_step = create(:automation_step, :api_call, automation: automation, position: 1)
          create(:api_response_report, automation_step: api_step, status: 'completed')
          
          expect(template.automation_running?).to be false
        end
      end
    end
  
    describe 'template isolation' do
      it 'only checks automations belonging to this template' do
        other_template = create(:automation_template)
        
        # This template - completed
        completed = create(:automation, automation_template: template)
        step = create(:automation_step, :pipeline, automation: completed, pipeline: pipeline)
        job = create(:pipeline_job, automation_step: step, pipeline: pipeline)
        harvest_job = create(:harvest_job, pipeline_job: job, harvest_definition: harvest_definition)
        create(:harvest_report,
               pipeline_job: job,
               harvest_job: harvest_job,
               extraction_status: :completed,
               transformation_status: :completed,
               load_status: :completed,
               delete_status: :completed)
        
        # Other template - running
        running = create(:automation, automation_template: other_template)
        running_step = create(:automation_step, :pipeline, automation: running, pipeline: pipeline)
        running_job = create(:pipeline_job, automation_step: running_step, pipeline: pipeline)
        running_harvest_job = create(:harvest_job, pipeline_job: running_job, harvest_definition: harvest_definition)
        create(:harvest_report,
               pipeline_job: running_job,
               harvest_job: running_harvest_job,
               extraction_status: :running,
               transformation_status: :queued,
               load_status: :queued,
               delete_status: :queued)
        
        expect(template.automation_running?).to be false
        expect(other_template.automation_running?).to be true
      end
    end
  end
end 