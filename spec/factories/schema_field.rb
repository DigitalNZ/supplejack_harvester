# frozen_string_literal: true

FactoryBot.define do
  factory :schema_field do
    name        { Faker::Name.unique.name }
  end
end