# frozen_string_literal: true

FactoryBot.define do
  factory :schema do
    name        { Faker::Name.unique.name }
  end
end
