# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AutomationSteps' do
  let(:user) { create(:user) }
  let!(:automation_template) { create(:automation_template) }
  let!(:automation) { create(:automation, automation_template: automation_template) }
  let!(:pipeline) { create(:pipeline) }
  let!(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }

  before do
    sign_in(user)
  end

  describe 'GET /automations/:automation_id/automation_steps/get_harvest_definitions' do
    it 'returns harvest definitions for the selected pipeline' do
      get get_harvest_definitions_automation_automation_steps_path(automation), params: { pipeline_id: pipeline.id }, xhr: true
      
      expect(response).to have_http_status :ok
      expect(response.body).to include harvest_definition.name
    end
  end
end 