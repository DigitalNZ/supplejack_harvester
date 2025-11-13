# spec/factories/job_error.rb
FactoryBot.define do
    factory :job_error do
      association :job_completion_summary
      association :job, factory: :extraction_job
      origin { "TestWorker" }
      process_type { :extraction }
      job_type { "ExtractionJob" }
      message { "StandardError: Test error" }
      stack_trace { [] }
  
      trait :transformation do
        association :job, factory: :transformation_job
        process_type { :transformation }
        job_type { "TransformationJob" }
      end
    end
  end