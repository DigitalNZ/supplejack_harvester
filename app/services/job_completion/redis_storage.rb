# frozen_string_literal: true

module JobCompletion
  class RedisStorage
    REDIS_KEY_PREFIX = 'job_completion'

    def self.store_completion_context(job_id, process_type, context)
      redis_key = build_redis_key(job_id, process_type)
      redis.lpush(redis_key, context.to_json)
      redis.expire(redis_key, 24.hours.to_i) # Expire after 24 hours as safety measure
    rescue StandardError => e
      Rails.logger.error "Failed to store completion context in Redis: #{e.message}"
      raise
    end

    def self.retrieve_completion_contexts(job_id, process_type)
      redis_key = build_redis_key(job_id, process_type)
      contexts = redis.lrange(redis_key, 0, -1)
      contexts.map { |context_json| JSON.parse(context_json, symbolize_names: true) }
    rescue StandardError => e
      Rails.logger.error "Failed to retrieve completion contexts from Redis: #{e.message}"
      []
    end

    def self.clear_completion_contexts(job_id, process_type)
      redis_key = build_redis_key(job_id, process_type)
      redis.del(redis_key)
    rescue StandardError => e
      Rails.logger.error "Failed to clear completion contexts from Redis: #{e.message}"
    end

    def self.get_all_contexts(job_id, process_type)
      retrieve_completion_contexts(job_id, process_type)
    end

    private

    def self.redis
      @redis ||= Sidekiq.redis { |conn| conn }
    end

    def self.build_redis_key(job_id, process_type)
      "#{REDIS_KEY_PREFIX}:#{process_type}:#{job_id}"
    end
  end
end
