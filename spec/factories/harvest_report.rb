# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_report do
    pipeline_job
    harvest_job
  end
end
