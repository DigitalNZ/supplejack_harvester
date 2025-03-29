# frozen_string_literal: true

FactoryBot.define do
  factory :api_response_report do
    association :automation_step
    status { 'completed' }
    response_code { 200 }
    response_body { '{"success": true}' }
    response_headers { '{"Content-Type": "application/json"}' }
    executed_at { Time.current }
  end
end 