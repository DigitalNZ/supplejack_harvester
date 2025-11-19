# spec/factories/job_error.rb
FactoryBot.define do
    factory :job_error do
      association :job_completion_summary
      job_id { create(:extraction_job).id }
      origin { "TestWorker#{SecureRandom.hex(4)}" }
      process_type { :extraction }
      job_type { "ExtractionJob" }
      message { "StandardError: Test error #{SecureRandom.hex(4)}" }
      stack_trace { ['No backtrace available'] }
  
      trait :transformation do
        job_id { create(:harvest_job).id }
        process_type { :transformation }
        job_type { "TransformationJob" }
      end
    end
  end