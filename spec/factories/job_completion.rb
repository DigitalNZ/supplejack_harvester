# frozen_string_literal: true


FactoryBot.define do
  factory :job_completion do
    association :job_completion_summary
    job_id { create(:extraction_job).id }
    origin { "TestWorker#{SecureRandom.hex(4)}" }
    process_type { :extraction }
    stop_condition_type { "user" }
    stop_condition_name { "test_condition#{SecureRandom.hex(4)}" }
    stop_condition_content { "if count > 100" }

    trait :transformation do
      job_id { create(:harvest_job).id }
      process_type { :transformation }
    end
  end
end

