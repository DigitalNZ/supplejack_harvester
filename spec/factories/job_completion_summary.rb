# frozen_string_literal: true

FactoryBot.define do
    factory :job_completion_summary do
      extraction_id { SecureRandom.uuid }
      extraction_name { "Test Extraction #{SecureRandom.hex(4)}" }
      completion_type { :error }
      completion_count { 1 }
      last_occurred_at { Time.current }
      completion_details do
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
        completion_type { :stop_condition }
        completion_details do
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
        completion_count { 3 }
        completion_details do
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
        completion_count { 0 }
        completion_details { [{"message" => "No errors occurred", "details" => {}, "timestamp" => Time.current.iso8601}] }  # Valid structure to satisfy validation
      end
    end
  end
  