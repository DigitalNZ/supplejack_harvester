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
               pages_extracted: 10, records_transformed: 8, records_loaded: 5,
               extraction_start_time: 1.hour.ago, extraction_end_time: 55.minutes.ago,
               transformation_end_time: 50.minutes.ago, load_end_time: 45.minutes.ago)
      end

      it 'shows metrics for the automation' do
        get automation_path(automation)

        expect(response).to have_http_status :ok
        expect(response.body).to include '10' # pages extracted
        expect(response.body).to include '8' # records transformed
        expect(response.body).to include '5' # records loaded
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