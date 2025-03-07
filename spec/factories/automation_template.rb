# frozen_string_literal: true

FactoryBot.define do
  factory :automation_template do
    sequence(:name) { |n| "Test Automation Template #{n}" }
    description { "This is a test automation template" }
    association :last_edited_by, factory: :user
    association :destination
  end
end 