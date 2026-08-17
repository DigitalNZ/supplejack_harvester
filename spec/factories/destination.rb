# frozen_string_literal: true

FactoryBot.define do
  factory :destination do
    # Destination validates that its name is unique, and one example can build more
    # than one: a harvest_report given only a harvest_job builds its own pipeline_job,
    # which builds its own destination. Faker::Company.name starts repeating itself
    # after a couple of hundred values, so those two draws could return the same name
    # and fail validation - apparently at random, depending on how many names the run
    # had already generated. A sequence cannot collide, and matches the
    # automation_template factory.
    sequence(:name) { |n| "Destination #{n}" }
    url  { 'http://www.localhost:3000' }
    api_key { 'testkey' }
  end
end
