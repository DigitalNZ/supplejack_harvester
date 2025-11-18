# frozen_string_literal: true

FactoryBot.define do
  factory :job_completion_summary do
    job_id { create(:extraction_job).id }
    job_type { "ExtractionJob" }
    process_type { :extraction }

    trait :transformation do
      job_id { create(:harvest_job).id }
      process_type { :transformation }
      job_type { "TransformationJob" }
    end
  end
end