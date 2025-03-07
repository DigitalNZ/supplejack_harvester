# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_report do
    # Both pipeline_job and harvest_job associations are required for most tests
    association :pipeline_job
    association :harvest_job
  end
end
