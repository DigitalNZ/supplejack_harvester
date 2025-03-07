# frozen_string_literal: true

FactoryBot.define do
  factory :automation do
    name { "Test Automation" }
    description { "This is a test automation" }
    association :destination
    association :automation_template
  end
end 