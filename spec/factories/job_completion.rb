# frozen_string_literal: true


FactoryBot.define do
  factory :job_completion do
    association :job_completion_summary
    association :job, factory: :extraction_job
    origin { "TestWorker" }
    process_type { :extraction }
    stop_condition_type { "user" }
    stop_condition_name { "test_condition" }
    stop_condition_content { "if count > 100" }

    trait :transformation do
      association :job, factory: :transformation_job
      process_type { :transformation }
    end
  end
end

