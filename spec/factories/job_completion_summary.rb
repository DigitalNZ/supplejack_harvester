# frozen_string_literal: true

FactoryBot.define do
  factory :job_completion_summary do
    source_id { "test-source-#{SecureRandom.hex(4)}" }
    source_name { "Test Source #{SecureRandom.hex(4)}" }
    job_type { "ExtractionJob" }
    process_type { :extraction }
    completion_count { 1 }

    trait :multiple_errors do
      completion_count { 3 }
    end

    trait :no_errors do
      completion_count { 0 }
    end

    trait :transformation do
      process_type { :transformation }
      job_type { "TransformationJob" }
    end
  end
end