# frozen_string_literal: true

FactoryBot.define do
  factory :automation_step_template do
    position { 0 }
    harvest_definition_ids { [] }
    association :automation_template
    association :pipeline
  end
end 