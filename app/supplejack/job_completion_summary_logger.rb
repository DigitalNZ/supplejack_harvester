# frozen_string_literal: true

module Supplejack
  class JobCompletionSummaryLogger

    def self.log_completion(params)
      worker_class = params[:worker_class]
      exception = params[:exception]
      extraction_id = params[:extraction_id]
      extraction_name = params[:extraction_name]
      details = params[:details] || {}
      message = params[:message]

      resolved_message = resolve_message(message, worker_class, exception)

      JobCompletionSummary.log_completion(
        extraction_id: extraction_id,
        extraction_name: extraction_name,
        message: resolved_message,
        details: build_completion_details(worker_class, exception, details)
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log #{worker_class.downcase} completion to JobCompletionSummary: #{e.message}"
    end

    def self.log_stop_condition_hit(params)
      extraction_definition = params[:extraction_definition]
      stop_condition_name = params[:stop_condition_name]
      stop_condition_content = params[:stop_condition_content]
      extraction_job = params[:extraction_job]
      harvest_job = params[:harvest_job]
      document = params[:document]
      additional_details = params[:additional_details] || {}

      JobCompletionSummary.log_stop_condition_hit(
        extraction_id: extraction_definition.id.to_s,
        extraction_name: extraction_definition.name,
        stop_condition_name: stop_condition_name,
        stop_condition_content: stop_condition_content,
        details: {
          extraction_job_id: extraction_job&.id,
          harvest_job_id: harvest_job&.id,
          pipeline_job_id: harvest_job&.pipeline_job&.id,
          page: extraction_definition.page,
          document_status: document&.status
        }.merge(additional_details)
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log stop condition hit to JobCompletionSummary: #{e.message}"
    end

    def self.resolve_message(message, worker_class, exception)
      return message if message.present?

      "#{worker_class} error: #{exception.class} - #{exception.message}"
    end

    def self.build_completion_details(worker_class, exception, custom_details)
      {
        worker_class: worker_class,
        exception_class: exception.class.name,
        exception_message: exception.message,
        stack_trace: exception.backtrace&.first(20),
        timestamp: Time.current.iso8601
      }.merge(custom_details)
    end

    def self.extract_from_extraction_definition(extraction_definition)
      harvest_definition = extraction_definition&.harvest_definition
      return nil unless harvest_definition&.source_id

      {
        extraction_id: harvest_definition.source_id,
        extraction_name: harvest_definition.name
      }
    end

    def self.extract_from_harvest_job(harvest_job)
      harvest_definition = harvest_job&.harvest_definition
      return nil unless harvest_definition&.source_id

      {
        extraction_id: harvest_definition.source_id,
        extraction_name: harvest_definition.name
      }
    end

    def self.extract_from_record_and_harvest_report(record, harvest_report)
      source_id = record.dig('transformed_record', 'source_id') ||
                  extract_source_id_from_harvest_report(harvest_report) ||
                  'unknown'
      extraction_name = record.dig('transformed_record', 'job_id') ||
                        extract_name_from_harvest_report(harvest_report) ||
                        'unknown'

      {
        extraction_id: source_id,
        extraction_name: extraction_name
      }
    end

    def self.extract_from_schedule(schedule)
      {
        extraction_id: "schedule_#{schedule.id}",
        extraction_name: "Schedule: #{schedule.name || 'Unnamed Schedule'}"
      }
    end


    private

    def self.extract_source_id_from_harvest_report(harvest_report)
      return nil unless harvest_report&.pipeline_job&.harvest_definitions&.first

      harvest_report.pipeline_job.harvest_definitions.first.source_id
    end

    def self.extract_name_from_harvest_report(harvest_report)
      return nil unless harvest_report&.pipeline_job&.harvest_definitions&.first

      harvest_report.pipeline_job.harvest_definitions.first.name
    end
  end
end
