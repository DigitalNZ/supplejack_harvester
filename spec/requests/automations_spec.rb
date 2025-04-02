# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Automations' do
  let(:user) { create(:user) }
  let!(:destination) { create(:destination) }
  let!(:automation_template) { create(:automation_template, destination: destination) }
  let!(:pipeline) { create(:pipeline) }
  let!(:automation) { create(:automation, destination: destination, automation_template: automation_template) }
  let!(:automation_step) { create(:automation_step, automation: automation, launched_by: user, pipeline: pipeline) }

  before do
    sign_in(user)
  end

  describe 'GET /automations/:id' do
    it 'displays the automation details' do
      get automation_path(automation)

      expect(response).to have_http_status :ok
      expect(response.body).to include CGI.escapeHTML(automation.name)
    end

    context 'with pipeline job and harvest reports' do
      let(:pipeline_job) { create(:pipeline_job, automation_step: automation_step, pipeline: pipeline) }
      let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }
      let(:extraction_job) { create(:extraction_job) }
      let(:harvest_job) { create(:harvest_job, pipeline_job: pipeline_job, harvest_definition: harvest_definition, extraction_job: extraction_job) }
      
      before do
        create(:harvest_report, pipeline_job: pipeline_job, harvest_job: harvest_job,
               extraction_status: 'completed',
               transformation_status: 'completed',
               load_status: 'completed',
               delete_status: 'completed',
               pages_extracted: 10, records_transformed: 8, records_loaded: 5,
               records_rejected: 3, records_deleted: 1,
               extraction_start_time: 1.hour.ago, extraction_end_time: 55.minutes.ago,
               transformation_end_time: 50.minutes.ago, load_end_time: 45.minutes.ago)
      end

      it 'shows metrics for the automation in the step-by-step table' do
        get automation_path(automation)

        expect(response).to have_http_status :ok
        
        # Check that metrics appear in the step data
        expect(response.body).to include('10') # pages extracted
        expect(response.body).to include('8') # records transformed
        expect(response.body).to include('5') # records loaded
        expect(response.body).to include('3') # records rejected
        expect(response.body).to include('1') # records deleted
      end
      
      it 'shows total metrics in the totals row' do
        get automation_path(automation)
        
        expect(response).to have_http_status :ok
        
        # Check for the totals row (update to match current HTML)
        expect(response.body).to include('<td colspan="5" class="text-start">Totals:</td>')
        
        # Check that totals appear
        expect(response.body).to include('10') # total pages extracted
        expect(response.body).to include('8') # total records transformed
        expect(response.body).to include('5') # total records loaded
        expect(response.body).to include('3') # total records rejected
        expect(response.body).to include('1') # total records deleted
      end
    end
    
    context 'with api call step' do
      let!(:api_automation) { create(:automation, destination: destination, automation_template: automation_template) }
      let!(:api_step) { create(:automation_step, :api_call, automation: api_automation, launched_by: user) }
      
      context 'when api call is completed' do
        before do
          create(:api_response_report, 
                 automation_step: api_step, 
                 status: 'completed',
                 response_code: '200',
                 response_body: '{"success": true}',
                 executed_at: 30.minutes.ago)
        end
        
        it 'shows api call information' do
          get automation_path(api_automation)
          
          expect(response).to have_http_status :ok
          expect(response.body).to include('API Call:')
          expect(response.body).to include('https://example.com/api')
          expect(response.body).to include('Completed')
        end
      end
      
      context 'when api call is errored' do
        before do
          create(:api_response_report, 
                 automation_step: api_step, 
                 status: 'errored',
                 response_code: '500',
                 response_body: 'Internal Server Error',
                 executed_at: 30.minutes.ago)
        end
        
        it 'shows api call error information' do
          get automation_path(api_automation)
          
          expect(response).to have_http_status :ok
          expect(response.body).to include('API Call:')
          expect(response.body).to include('Errored')
          expect(response.body).to include('Internal Server Error')
        end
      end
    end
  end

  describe 'DELETE /automations/:id' do
    it 'destroys the automation' do
      expect {
        delete automation_path(automation)
      }.to change(Automation, :count).by(-1)
    end

    it 'redirects to the templates index' do
      delete automation_path(automation)
      expect(response).to redirect_to(automation_templates_path)
    end
  end

  describe 'POST /automations/:id/run' do
    it 'starts the automation' do
      expect(AutomationWorker).to receive(:perform_async)
      expect_any_instance_of(Automation).to receive(:run).and_call_original
      
      post run_automation_path(automation)
      
      expect(response).to redirect_to(automation_path(automation))
    end
    
    context 'with mixed step types' do
      let!(:mixed_automation) { create(:automation, destination: destination, automation_template: automation_template) }
      let!(:pipeline_step) { create(:automation_step, :pipeline, automation: mixed_automation, position: 0) }
      let!(:api_step) { create(:automation_step, :api_call, automation: mixed_automation, position: 1) }
      
      it 'starts the automation with different step types' do
        expect(AutomationWorker).to receive(:perform_async)
        
        post run_automation_path(mixed_automation)
        
        expect(response).to redirect_to(automation_path(mixed_automation))
      end
    end

    context 'when automation cannot run' do
      before do
        allow_any_instance_of(Automation).to receive(:can_run?).and_return(false)
      end

      it 'redirects with an alert' do
        post run_automation_path(automation)
        
        expect(response).to redirect_to(automation_path(automation))
        expect(flash[:alert]).to be_present
      end
    end
  end
end 