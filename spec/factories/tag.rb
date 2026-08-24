# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    # A sequence rather than Faker: the name is unique, and so is the slug derived from
    # it, so two draws colliding would fail validation at random.
    sequence(:name) { |n| "Tag #{n}" }
  end
end
