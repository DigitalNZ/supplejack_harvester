# frozen_string_literal: true

FactoryBot.define do
  factory :pipeline_job do
    key { SecureRandom.hex }
    harvest_definitions_to_run { [] }

    pipeline
    destination
  end
end
