# frozen_string_literal: true

# Test data script for JobCompletionSummary
# Run this in Rails console: load 'test_data_script.rb'

puts 'Creating test data for JobCompletionSummary...'

# Clear existing test data (optional - remove if you want to keep existing data)
JobCompletionSummary.destroy_all

# Create test data for different scenarios
test_data = [
  {
    source_id: 'extraction_001',
    source_name: 'News API Extraction',
    process_type: :extraction,
    job_type: 'ExtractionJob',
    completion_type: :error,
    completion_entries: [
      {
        message: 'Connection timeout after 30 seconds',
        details: {
          worker_class: 'ExtractionWorker',
          job_id: '12345',
          pipeline_job_id: 'pipeline_001',
          stack_trace: "Timeout::Error: execution expired\n  at /app/workers/extraction_worker.rb:45",
          context: { url: 'https://newsapi.org/v2/everything', retry_count: 3 }
        },
        timestamp: 2.hours.ago.iso8601
      },
      {
        message: 'Invalid JSON response from API',
        details: {
          worker_class: 'ExtractionWorker',
          job_id: '12346',
          pipeline_job_id: 'pipeline_001',
          stack_trace: "JSON::ParserError: unexpected token at 'Invalid JSON'",
          context: { url: 'https://newsapi.org/v2/everything', page: 2 }
        },
        timestamp: 1.hour.ago.iso8601
      }
    ],
    completion_count: 2,
    last_occurred_at: 1.hour.ago
  },
  {
    source_id: 'extraction_002',
    source_name: 'RSS Feed Parser',
    process_type: :extraction,
    job_type: 'ExtractionJob',
    completion_type: :stop_condition,
    completion_entries: [
      {
        message: 'Stop condition met: No new articles found',
        details: {
          stop_condition_name: 'No New Content',
          stop_condition_content: 'articles.count == 0',
          stop_condition_type: 'user_defined',
          worker_class: 'ExtractionWorker',
          job_id: '12347',
          pipeline_job_id: 'pipeline_002'
        },
        timestamp: 3.hours.ago.iso8601
      }
    ],
    completion_count: 1,
    last_occurred_at: 3.hours.ago
  },
  {
    source_id: 'extraction_004',
    source_name: 'API Rate Limiter',
    process_type: :extraction,
    job_type: 'ExtractionJob',
    completion_type: :stop_condition,
    completion_entries: [
      {
        message: 'System stop condition: Maximum retry attempts exceeded',
        details: {
          stop_condition_name: 'Max Retries',
          stop_condition_content: 'retry_count >= 5',
          stop_condition_type: 'system',
          worker_class: 'ExtractionWorker',
          job_id: '12355',
          pipeline_job_id: 'pipeline_007',
          context: { max_retries: 5, current_retries: 5, last_error: 'Connection timeout' }
        },
        timestamp: 2.hours.ago.iso8601
      }
    ],
    completion_count: 1,
    last_occurred_at: 2.hours.ago
  },
  {
    source_id: 'transformation_002',
    source_name: 'Data Quality Checker',
    process_type: :transformation,
    job_type: 'TransformationJob',
    completion_type: :stop_condition,
    completion_entries: [
      {
        message: 'User stop condition: Data quality threshold not met',
        details: {
          stop_condition_name: 'Quality Threshold',
          stop_condition_content: 'quality_score < 0.8',
          stop_condition_type: 'user_defined',
          worker_class: 'TransformationWorker',
          job_id: '12356',
          pipeline_job_id: 'pipeline_008',
          context: { quality_score: 0.65, threshold: 0.8, records_processed: 150 }
        },
        timestamp: 1.hour.ago.iso8601
      },
      {
        message: 'System stop condition: Memory usage exceeded',
        details: {
          stop_condition_name: 'Memory Limit',
          stop_condition_content: 'memory_usage > 2.gigabytes',
          stop_condition_type: 'system',
          worker_class: 'TransformationWorker',
          job_id: '12357',
          pipeline_job_id: 'pipeline_008',
          context: { memory_usage: '2.1GB', limit: '2GB', records_processed: 200 }
        },
        timestamp: 45.minutes.ago.iso8601
      }
    ],
    completion_count: 2,
    last_occurred_at: 45.minutes.ago
  },
  {
    source_id: 'loading_002',
    source_name: 'Database Loader',
    process_type: :loading,
    job_type: 'LoadJob',
    completion_type: :stop_condition,
    completion_entries: [
      {
        message: 'User stop condition: Duplicate records detected',
        details: {
          stop_condition_name: 'Duplicate Prevention',
          stop_condition_content: 'duplicate_count > 10',
          stop_condition_type: 'user_defined',
          worker_class: 'LoadWorker',
          job_id: '12358',
          pipeline_job_id: 'pipeline_009',
          context: { duplicate_count: 15, threshold: 10, total_records: 100 }
        },
        timestamp: 30.minutes.ago.iso8601
      }
    ],
    completion_count: 1,
    last_occurred_at: 30.minutes.ago
  },
  {
    source_id: 'transformation_001',
    source_name: 'Data Transformation Pipeline',
    process_type: :transformation,
    job_type: 'TransformationJob',
    completion_type: :error,
    completion_entries: [
      {
        message: "Field validation failed: missing required field 'title'",
        details: {
          worker_class: 'TransformationWorker',
          job_id: '12348',
          pipeline_job_id: 'pipeline_003',
          stack_trace: "ValidationError: Title is required\n  at /app/transformers/article_transformer.rb:23",
          context: { record_id: 'rec_001', field_mappings: { title: 'headline' } }
        },
        timestamp: 4.hours.ago.iso8601
      },
      {
        message: 'Schema validation error: invalid date format',
        details: {
          worker_class: 'TransformationWorker',
          job_id: '12349',
          pipeline_job_id: 'pipeline_003',
          stack_trace: "Date::Error: invalid date\n  at /app/transformers/date_transformer.rb:12",
          context: { record_id: 'rec_002', date_field: 'published_at', value: 'invalid-date' }
        },
        timestamp: 2.hours.ago.iso8601
      }
    ],
    completion_count: 2,
    last_occurred_at: 2.hours.ago
  },
  {
    source_id: 'loading_001',
    source_name: 'API Load Process',
    process_type: :loading,
    job_type: 'LoadJob',
    completion_type: :error,
    completion_entries: [
      {
        message: 'API rate limit exceeded',
        details: {
          worker_class: 'LoadWorker',
          job_id: '12350',
          pipeline_job_id: 'pipeline_004',
          stack_trace: "RateLimitError: 429 Too Many Requests\n  at /app/loaders/api_loader.rb:67",
          context: { api_endpoint: 'https://api.example.com/records', retry_after: 60 }
        },
        timestamp: 30.minutes.ago.iso8601
      }
    ],
    completion_count: 1,
    last_occurred_at: 30.minutes.ago
  },
  {
    source_id: 'deletion_001',
    source_name: 'Cleanup Process',
    process_type: :deletion,
    job_type: 'DeleteJob',
    completion_type: :stop_condition,
    completion_entries: [
      {
        message: 'System stop condition: Maximum deletion limit reached',
        details: {
          stop_condition_name: 'Max Deletions',
          stop_condition_content: 'deleted_count >= 1000',
          stop_condition_type: 'system',
          worker_class: 'DeleteWorker',
          job_id: '12351',
          pipeline_job_id: 'pipeline_005'
        },
        timestamp: 6.hours.ago.iso8601
      }
    ],
    completion_count: 1,
    last_occurred_at: 6.hours.ago
  },
  {
    source_id: 'extraction_003',
    source_name: 'Social Media Scraper',
    process_type: :extraction,
    job_type: 'ExtractionJob',
    completion_type: :error,
    completion_entries: [
      {
        message: 'Authentication failed: Invalid API key',
        details: {
          worker_class: 'ExtractionWorker',
          job_id: '12352',
          pipeline_job_id: 'pipeline_006',
          stack_trace: "AuthenticationError: Invalid API key\n  at /app/workers/social_extraction_worker.rb:34",
          context: { api_key: 'sk-***', endpoint: 'https://api.twitter.com/2/tweets' }
        },
        timestamp: 5.hours.ago.iso8601
      },
      {
        message: 'Rate limit exceeded: Too many requests',
        details: {
          worker_class: 'ExtractionWorker',
          job_id: '12353',
          pipeline_job_id: 'pipeline_006',
          stack_trace: "RateLimitError: 429 Too Many Requests\n  at /app/workers/social_extraction_worker.rb:45",
          context: { api_key: 'sk-***', retry_after: 900 }
        },
        timestamp: 4.hours.ago.iso8601
      },
      {
        message: 'Network timeout: Connection lost',
        details: {
          worker_class: 'ExtractionWorker',
          job_id: '12354',
          pipeline_job_id: 'pipeline_006',
          stack_trace: "Net::TimeoutError: execution expired\n  at /app/workers/social_extraction_worker.rb:67",
          context: { url: 'https://api.twitter.com/2/tweets', timeout: 30 }
        },
        timestamp: 1.hour.ago.iso8601
      }
    ],
    completion_count: 3,
    last_occurred_at: 1.hour.ago
  }
]

# Create the records
test_data.each do |data|
  JobCompletionSummary.create!(data)
  puts "Created JobCompletionSummary for #{data[:source_name]} (#{data[:completion_count]} entries)"
end

puts "\nTest data creation complete!"
puts "Total JobCompletionSummary records: #{JobCompletionSummary.count}"
puts 'Records by process type:'
JobCompletionSummary.group(:process_type).count.each do |type, count|
  puts "  #{type}: #{count}"
end
puts 'Records by completion type:'
JobCompletionSummary.group(:completion_type).count.each do |type, count|
  puts "  #{type}: #{count}"
end
