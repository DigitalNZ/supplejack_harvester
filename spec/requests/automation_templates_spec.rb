# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AutomationTemplates' do
  let(:user) { create(:user) }
  let!(:destination) { create(:destination) }
  let!(:automation_template) { create(:automation_template, destination: destination) }

  before do
    sign_in(user)
  end

  describe 'GET /automation_templates' do
    it 'displays a list of automation templates' do
      get automation_templates_path

      expect(response).to have_http_status :ok
      expect(response.body).to include CGI.escapeHTML(automation_template.name)
    end

    # The same card of controls the pipelines and jobs lists are narrowed from - see
    # shared/_filter_bar, which all three render.
    it 'is narrowed from the filter bar every list wears' do
      get automation_templates_path

      expect(response.body).to include %(<form class="card bg-light mb-3" action="/automation_templates")
    end

    it 'says how much of the list a search left' do
      create(:automation_template, name: 'Not the one')

      get automation_templates_path(search: automation_template.name)

      expect(response.body).to include '1 of 2 templates match'
    end

    it 'searches by name' do
      other = create(:automation_template, name: 'Not the one')

      get automation_templates_path(search: automation_template.name)

      expect(response.body).to include CGI.escapeHTML(automation_template.name)
      expect(response.body).not_to include CGI.escapeHTML(other.name)
    end

    # A pipeline's templates are the few it has, so there is nothing there to narrow.
    it "leaves the filter bar off a pipeline's own templates" do
      pipeline = create(:pipeline)

      get pipeline_automation_templates_path(pipeline)

      expect(response.body).not_to include 'card bg-light mb-3'
    end
  end

  describe 'GET /automation_templates/:id' do
    it 'displays the automation template' do
      get automation_template_path(automation_template)

      expect(response).to have_http_status :ok
      expect(response.body).to include CGI.escapeHTML(automation_template.name)
    end
  end

  describe 'the description on GET /automation_templates/:id' do
    it 'offers the three description states, and the collapsed one leads' do
      get automation_template_path(automation_template)

      expect(response.body).to match(/class="js-description-collapsed"/)
      expect(response.body).to match(/js-description-expanded/)
      expect(response.body).to match(/<textarea[^>]*name="automation_template\[description\]"/)
    end

    it 'renders the description as markdown' do
      automation_template.update(description: 'Runs **weekly**.')

      get automation_template_path(automation_template)

      expect(response.body).to include '<strong>weekly</strong>'
    end
  end

  describe 'GET /automation_templates/new' do
    it 'displays the new template form' do
      get new_automation_template_path

      expect(response).to have_http_status :ok
      expect(response.body).to include 'New Automation Template'
    end
  end

  describe 'GET /automation_templates/:id/edit' do
    it 'displays the edit template form' do
      get edit_automation_template_path(automation_template)

      expect(response).to have_http_status :ok
      expect(response.body).to include 'Edit Automation Template'
    end
  end

  describe 'POST /automation_templates' do
    context 'with valid attributes' do
      let(:valid_attributes) { { name: 'New Template', description: 'Description', destination_id: destination.id } }

      it 'creates a new automation template' do
        expect {
          post automation_templates_path, params: { automation_template: valid_attributes }
        }.to change(AutomationTemplate, :count).by(1)
      end

      it 'redirects to the templates index' do
        post automation_templates_path, params: { automation_template: valid_attributes }
        expect(response).to redirect_to(automation_templates_path)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { name: '', description: 'Description' } }

      it 'does not create a new automation template' do
        expect {
          post automation_templates_path, params: { automation_template: invalid_attributes }
        }.not_to change(AutomationTemplate, :count)
      end

      it 'renders the new template form' do
        post automation_templates_path, params: { automation_template: invalid_attributes }
        expect(response.body).to include 'New Automation Template'
      end
    end
  end

  describe 'PATCH /automation_templates/:id' do
    context 'with valid attributes' do
      let(:valid_attributes) { { name: 'Updated Template' } }

      it 'updates the automation template' do
        patch automation_template_path(automation_template), params: { automation_template: valid_attributes }
        automation_template.reload
        expect(automation_template.name).to eq('Updated Template')
      end

      it 'saves a description on its own' do
        patch automation_template_path(automation_template), params: {
          automation_template: { description: 'Runs weekly.' }
        }

        expect(automation_template.reload.description).to eq 'Runs weekly.'
      end

      it 'redirects to the template show page' do
        patch automation_template_path(automation_template), params: { automation_template: valid_attributes }
        expect(response).to redirect_to(automation_template_path(automation_template))
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { name: '' } }

      it 'does not update the automation template' do
        original_name = automation_template.name
        patch automation_template_path(automation_template), params: { automation_template: invalid_attributes }
        automation_template.reload
        expect(automation_template.name).to eq(original_name)
      end

      it 'renders the edit template form' do
        patch automation_template_path(automation_template), params: { automation_template: invalid_attributes }
        expect(response.body).to include 'Edit Automation Template'
      end
    end
  end

  describe 'DELETE /automation_templates/:id' do
    it 'destroys the automation template' do
      expect {
        delete automation_template_path(automation_template)
      }.to change(AutomationTemplate, :count).by(-1)
    end

    it 'redirects to the templates index' do
      delete automation_template_path(automation_template)
      expect(response).to redirect_to(automation_templates_path)
    end
    
    it 'destroys all associated automations' do
      # Create automations associated with the template
      create_list(:automation, 3, automation_template: automation_template)
      
      expect {
        delete automation_template_path(automation_template)
      }.to change(Automation, :count).by(-3)
    end
    
    it 'includes the count of deleted automations in the notice message' do
      create_list(:automation, 2, automation_template: automation_template)
      
      delete automation_template_path(automation_template)
      
      expect(flash[:notice]).to include("along with 2 automation")
    end
    
    it 'displays a simple message when no automations are deleted' do
      delete automation_template_path(automation_template)

      expect(flash[:notice]).to include('successfully deleted')
      expect(flash[:notice]).to include('along with 0 automation')
    end
  end

  describe 'POST /automation_templates/:id/run_automation' do
    it 'creates a new automation from the template' do
      expect {
        post run_automation_automation_template_path(automation_template)
      }.to change(Automation, :count).by(1)
    end

    it 'redirects to the template show page' do
      post run_automation_automation_template_path(automation_template)
      expect(response).to redirect_to(automation_template_path(automation_template))
    end
  end
end 