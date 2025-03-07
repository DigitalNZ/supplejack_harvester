# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::AutomationTemplates", type: :request do
  let!(:destination) { create(:destination) }
  let!(:admin_user) { create(:user, api_key: 'key', role: :admin) }
  let!(:user) { create(:user, api_key: 'user_key') }
  let!(:automation_template) { create(:automation_template, destination: destination) }

  describe "POST /run" do
    context 'when the user is using an admin api key' do
      context 'when there are no running automations from this template' do
        it "creates and runs an automation" do
          expect_any_instance_of(AutomationTemplate).to receive(:run_automation).and_return(
            [build_stubbed(:automation, id: 123), "Automation was successfully created and started", true]
          )

          post run_api_automation_template_path(automation_template), headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['status']).to eq('success')
          expect(parsed_response['message']).to eq('Automation was successfully created and started')
          expect(parsed_response['automation_id']).to eq(123)
        end
      end

      context 'when there is already a running automation from this template' do
        it "returns an error" do
          expect_any_instance_of(AutomationTemplate).to receive(:run_automation).and_return(
            [nil, "Cannot run automation - an automation from this template is already running", false]
          )

          post run_api_automation_template_path(automation_template), headers: { 
            "Authorization" => "Token token=#{admin_user.api_key}"
          }

          parsed_response = JSON.parse(response.body)

          expect(parsed_response['status']).to eq('failed')
          expect(parsed_response['message']).to eq('Cannot run automation - an automation from this template is already running')
          expect(response).to have_http_status(422)
        end
      end
    end

    context 'when the user is not using an admin api key' do
      it "returns a 401" do
        post run_api_automation_template_path(automation_template), headers: {
          "Authorization" => "Token token=#{user.api_key}"
        }

        expect(response).to have_http_status(401)
      end
    end

    context 'when the user is not using an api key' do
      it "returns a 401" do
        post run_api_automation_template_path(automation_template), headers: {
          "Authorization" => "Token token="
        }

        expect(response).to have_http_status(401)
      end
    end

    context 'when the template does not exist' do
      it "returns a 404" do
        post run_api_automation_template_path(id: 999999), headers: {
          "Authorization" => "Token token=#{admin_user.api_key}"
        }

        parsed_response = JSON.parse(response.body)

        expect(parsed_response['status']).to eq('failed')
        expect(parsed_response['message']).to eq('Automation template not found')
        expect(response).to have_http_status(404)
      end
    end
  end
end 