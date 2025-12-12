# frozen_string_literal: true

FactoryBot.define do
  factory :automation_step do
    sequence(:position) { |n| n }
    harvest_definition_ids { [] }
    step_type { 'pipeline' }
    association :automation
    association :pipeline
    association :launched_by, factory: :user

    trait :pipeline do
      step_type { 'pipeline' }
      pipeline { association :pipeline }
    end

    trait :api_call do
      step_type { 'api_call' }
      pipeline { nil }
      api_method { 'GET' }
      api_url { 'https://example.com/api' }
      api_headers { '{"Content-Type": "application/json"}' }
      api_body { '{"test": "data"}' }
    end

    trait :independent_extraction do
      step_type { 'independent_extraction' }
      pipeline { nil }
      link_selector { '//a/@href' }
      association :extraction_definition
    end
  end
end
