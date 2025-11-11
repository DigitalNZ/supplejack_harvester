# frozen_string_literal: true

FactoryBot.define do
  factory :job_completion do
    source_id { "test-source-#{SecureRandom.hex(4)}" }
    source_name { "Test Source #{SecureRandom.hex(4)}" }
    origin { "TestWorker" }
    job_type { "ExtractionJob" }
    process_type { :extraction }
    completion_type { :error }
    message { "Test error message" }
    message_prefix { "ERROR" }
    stack_trace { ["/app/test.rb:1:in `test_method'"] }
    details do
      {
        "exception_class" => "StandardError",
        "exception_message" => "Test error message",
        "job_id" => SecureRandom.hex(8),
        "pipeline_job_id" => SecureRandom.hex(8)
      }
    end

    trait :stop_condition do
      completion_type { :stop_condition }
      message { "Stop condition 'test_condition' was triggered" }
      message_prefix { "STOP" }
      stack_trace { ["No stack trace for stop condition"] }
      details do
        {
          "stop_condition_name" => "test_condition",
          "stop_condition_content" => "if records.count > 100",
          "stop_condition_type" => "user"
        }
      end
    end

    trait :transformation do
      process_type { :transformation }
      job_type { "TransformationJob" }
    end
  end
end

