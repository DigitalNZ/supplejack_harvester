# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AutomationStepTemplates' do
  let(:user) { create(:user) }
  let!(:automation_template) { create(:automation_template) }
  let!(:pipeline) { create(:pipeline) }
  let!(:automation_step_template) { create(:automation_step_template, automation_template: automation_template, pipeline: pipeline) }

  before do
    sign_in(user)
  end

  describe 'GET /automation_templates/:automation_template_id/automation_step_templates/new' do
    it 'displays the new step template form' do
      get new_automation_template_automation_step_template_path(automation_template)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'New Step Template'
    end
  end

  describe 'GET /automation_templates/:automation_template_id/automation_step_templates/:id/edit' do
    it 'displays the edit step template form' do
      get edit_automation_template_automation_step_template_path(automation_template, automation_step_template)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Edit Step Template'
    end
  end

  describe 'POST /automation_templates/:automation_template_id/automation_step_templates' do
    context 'with valid attributes' do
      let(:valid_attributes) { { pipeline_id: pipeline.id, position: 1 } }

      it 'creates a new automation step template' do
        expect {
          post automation_template_automation_step_templates_path(automation_template), params: { automation_step_template: valid_attributes }
        }.to change(AutomationStepTemplate, :count).by(1)
      end

      it 'redirects to the template show page' do
        post automation_template_automation_step_templates_path(automation_template), params: { automation_step_template: valid_attributes }
        expect(response).to redirect_to(automation_template_path(automation_template))
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { pipeline_id: nil, position: 1 } }

      it 'does not create a new automation step template' do
        expect {
          post automation_template_automation_step_templates_path(automation_template), params: { automation_step_template: invalid_attributes }
        }.not_to change(AutomationStepTemplate, :count)
      end

      it 'renders the new step template form' do
        post automation_template_automation_step_templates_path(automation_template), params: { automation_step_template: invalid_attributes }
        expect(response.body).to include 'New Step Template'
      end
    end
  end

  describe 'PATCH /automation_templates/:automation_template_id/automation_step_templates/:id' do
    context 'with valid attributes' do
      let(:new_pipeline) { create(:pipeline, name: 'New Pipeline') }
      let(:valid_attributes) { { pipeline_id: new_pipeline.id } }

      it 'updates the automation step template' do
        patch automation_template_automation_step_template_path(automation_template, automation_step_template), params: { automation_step_template: valid_attributes }
        automation_step_template.reload
        expect(automation_step_template.pipeline_id).to eq(new_pipeline.id)
      end

      it 'redirects to the template show page' do
        patch automation_template_automation_step_template_path(automation_template, automation_step_template), params: { automation_step_template: valid_attributes }
        expect(response).to redirect_to(automation_template_path(automation_template))
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { pipeline_id: nil } }

      it 'does not update the automation step template' do
        original_pipeline_id = automation_step_template.pipeline_id
        patch automation_template_automation_step_template_path(automation_template, automation_step_template), params: { automation_step_template: invalid_attributes }
        automation_step_template.reload
        expect(automation_step_template.pipeline_id).to eq(original_pipeline_id)
      end

      it 'renders the edit step template form' do
        patch automation_template_automation_step_template_path(automation_template, automation_step_template), params: { automation_step_template: invalid_attributes }
        expect(response.body).to include 'Edit Step Template'
      end
    end
  end

  describe 'DELETE /automation_templates/:automation_template_id/automation_step_templates/:id' do
    it 'destroys the automation step template' do
      expect {
        delete automation_template_automation_step_template_path(automation_template, automation_step_template)
      }.to change(AutomationStepTemplate, :count).by(-1)
    end

    it 'redirects to the template show page' do
      delete automation_template_automation_step_template_path(automation_template, automation_step_template)
      expect(response).to redirect_to(automation_template_path(automation_template))
    end

    it 'reorders the remaining step templates' do
      # Create additional steps with different positions
      step1 = create(:automation_step_template, automation_template: automation_template, position: 0, pipeline: pipeline)
      step2 = create(:automation_step_template, automation_template: automation_template, position: 1, pipeline: pipeline)
      step3 = create(:automation_step_template, automation_template: automation_template, position: 2, pipeline: pipeline)

      # Delete the middle step
      delete automation_template_automation_step_template_path(automation_template, step2)

      # The third step should now have position 1
      step3.reload
      expect(step3.position).to eq(1)
    end
  end

  describe 'GET /automation_templates/:automation_template_id/automation_step_templates/get_harvest_definitions' do
    let(:harvest_definition) { create(:harvest_definition, pipeline: pipeline) }

    before do
      harvest_definition # Ensure the harvest definition is created
    end

    it 'returns harvest definitions for the selected pipeline' do
      get get_harvest_definitions_automation_template_automation_step_templates_path(automation_template), params: { pipeline_id: pipeline.id }, xhr: true
      
      expect(response).to have_http_status :ok
      expect(response.body).to include harvest_definition.name
    end
  end
end 