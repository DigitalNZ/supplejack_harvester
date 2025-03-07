# frozen_string_literal: true

FactoryBot.define do
  factory :automation_step do
    sequence(:position) { |n| n }
    harvest_definition_ids { [] }
    association :automation
    association :pipeline
    association :launched_by, factory: :user
  end
end 