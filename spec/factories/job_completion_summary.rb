# frozen_string_literal: true

FactoryBot.define do
    factory :job_completion_summary do
      extraction_id { SecureRandom.uuid }
      extraction_name { "Test Extraction #{SecureRandom.hex(4)}" }
      error_type { "error" }
      error_count { 1 }
      first_error_at { Time.current }
      last_error_at { Time.current }
      error_details do
        [
          {
            "message" => "Test error message",
            "details" => {
              "worker_class" => "TestWorker",
              "job_id" => SecureRandom.hex(8),
              "context" => { "test" => true }
            },
            "timestamp" => Time.current.iso8601
          }
        ]
      end
  
      trait :stop_condition do
        error_type { "stop condition" }
        error_details do
          [
            {
              "message" => "Stop condition 'test_condition' was triggered",
              "details" => {
                "stop_condition_name" => "test_condition",
                "stop_condition_content" => "if records.count > 100",
                "condition_type" => "stop_condition"
              },
              "timestamp" => Time.current.iso8601
            }
          ]
        end
      end
  
      trait :multiple_errors do
        error_count { 3 }
        error_details do
          [
            {
              "message" => "First error",
              "details" => { "worker_class" => "Worker1" },
              "timestamp" => 3.hours.ago.iso8601
            },
            {
              "message" => "Second error", 
              "details" => { "worker_class" => "Worker2" },
              "timestamp" => 2.hours.ago.iso8601
            },
            {
              "message" => "Third error",
              "details" => { "worker_class" => "Worker3" },
              "timestamp" => 1.hour.ago.iso8601
            }
          ]
        end
      end
  
      trait :no_errors do
        error_count { 0 }
        error_details { [{"message" => "", "details" => {}, "timestamp" => Time.current.iso8601}] }  # Empty structure to satisfy validation
      end
    end
  end
  