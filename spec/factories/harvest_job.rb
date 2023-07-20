# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_job do
    harvest_definition
    extraction_job
    key { SecureRandom.hex }

    trait(:completed) do
      status { 'completed' }

      after(:create) do |harvest_job|
        transformation_definition = create(:transformation_definition, pipeline: harvest_job.pipeline)

        create(:extraction_job, status: 'completed', start_time: 2.hours.ago, end_time: 1.hour.ago, harvest_job:)

        create_list(:transformation_job, 2) do |transformation_job, i|
          transformation_job.update(transformation_definition:, harvest_job:, status: 'completed', page: i,
                                    start_time: 30.minutes.ago, end_time: 28.minutes.ago)
        end

        create_list(:load_job, 2, status: 'completed', start_time: 28.minutes.ago, end_time: 24.minutes.ago, harvest_job:)
      end
    end
  end
end
