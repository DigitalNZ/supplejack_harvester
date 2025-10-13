# frozen_string_literal: true

FactoryBot.define do
  # Helper method to create completion detail entries
  sequence :completion_detail do |n|
    {
      "message" => "Error #{n}",
      "details" => {
        "exception_class" => "StandardError",
        "exception_message" => "Error #{n}",
        "stack_trace" => ["/app/test.rb:#{n}:in `test_method'"],
        "job_id" => SecureRandom.hex(8),
        "pipeline_job_id" => SecureRandom.hex(8),
        "context" => { "test" => true }
      },
      "timestamp" => n.hours.ago.iso8601,
      "origin" => "Worker#{n}",
      "job_id" => SecureRandom.hex(8),
      "pipeline_job_id" => SecureRandom.hex(8),
      "stack_trace" => ["/app/test.rb:#{n}:in `test_method'"],
      "context" => { "test" => true }
    }
  end

  factory :job_completion_summary do
      source_id { "test-source-#{SecureRandom.hex(4)}" }
      source_name { "Test Source #{SecureRandom.hex(4)}" }
      job_type { "ExtractionJob" }
      process_type { :extraction }
      completion_type { :error }
      completion_count { 1 }
      last_completed_at { Time.current }
      completion_entries do
        [
          {
            "message" => "Test error message",
            "details" => {
              "exception_class" => "StandardError",
              "exception_message" => "Test error message",
              "stack_trace" => ["/app/test.rb:1:in `test_method'"],
              "job_id" => SecureRandom.hex(8),
              "pipeline_job_id" => SecureRandom.hex(8),
              "context" => { "test" => true }
            },
            "timestamp" => Time.current.iso8601,
            "origin" => "TestWorker",
            "job_id" => SecureRandom.hex(8),
            "pipeline_job_id" => SecureRandom.hex(8),
            "stack_trace" => ["/app/test.rb:1:in `test_method'"],
            "context" => { "test" => true }
          }
        ]
      end
  
      trait :stop_condition do
        completion_type { :stop_condition }
        completion_entries do
          [
            {
              "message" => "Stop condition 'test_condition' was triggered",
              "details" => {
                "stop_condition_name" => "test_condition",
                "stop_condition_content" => "if records.count > 100",
                "stop_condition_type" => "user"
              },
              "timestamp" => Time.current.iso8601,
              "origin" => "Extraction::Execution",
              "job_id" => SecureRandom.hex(8),
              "pipeline_job_id" => SecureRandom.hex(8),
              "stack_trace" => nil,
              "context" => {}
            }
          ]
        end
      end
  
      trait :multiple_errors do
        completion_count { 3 }
        completion_entries do
          Array.new(3) { |i| generate(:completion_detail, i + 1) }
        end
      end
  
      trait :no_errors do
        completion_count { 0 }
        completion_entries { [{"message" => "No errors occurred", "details" => {}, "timestamp" => Time.current.iso8601, "context" => {}}] }  # Valid structure to satisfy validation
      end

      trait :transformation do
        process_type { :transformation }
        job_type { "TransformationJob" }
      end
    end
  end
  