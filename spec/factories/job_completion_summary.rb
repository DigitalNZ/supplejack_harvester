# frozen_string_literal: true

FactoryBot.define do
  # Helper method to create completion detail entries
  sequence :completion_detail do |n|
    {
      "message" => "Error #{n}",
      "details" => { "worker_class" => "Worker#{n}" },
      "timestamp" => n.hours.ago.iso8601,
      "worker_class" => "Worker#{n}"
    }
  end

  factory :job_completion_summary do
      source_id { SecureRandom.uuid }
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
              "worker_class" => "TestWorker",
              "job_id" => SecureRandom.hex(8),
              "context" => { "test" => true }
            },
            "timestamp" => Time.current.iso8601,
            "worker_class" => "TestWorker",
            "job_id" => SecureRandom.hex(8),
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
                "condition_type" => "stop_condition"
              },
              "timestamp" => Time.current.iso8601,
              "stop_condition_name" => "test_condition",
              "stop_condition_content" => "if records.count > 100",
              "is_system_condition" => false
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
  