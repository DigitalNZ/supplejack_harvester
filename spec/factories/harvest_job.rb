# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_job do
    harvest_definition
    extraction_job
    key { SecureRandom.hex }

    trait(:completed) do
      status { 'completed' }

      after(:create) do |harvest_job|
        create(:transformation_definition, pipeline: harvest_job.pipeline_job.pipeline)

        create(:extraction_job, status: 'completed', start_time: 2.hours.ago, end_time: 1.hour.ago, harvest_job:)
      end
    end
  end
end
