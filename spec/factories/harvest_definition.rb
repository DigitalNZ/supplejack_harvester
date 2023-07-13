# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_definition do
    name { Faker::Company.name }
    source_id { 'test' }

    association :extraction_definition
    association :transformation_definition
  end
end
