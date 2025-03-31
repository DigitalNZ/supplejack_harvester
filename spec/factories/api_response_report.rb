# frozen_string_literal: true

FactoryBot.define do
  factory :api_response_report do
    status { 'completed' }
    response_code { '200' }
    response_body { '{"success": true}' }
    response_headers { '{"Content-Type": "application/json"}' }
    executed_at { Time.current }
    association :automation_step, :api_call, factory: :automation_step
  end
end 