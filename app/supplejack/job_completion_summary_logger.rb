# frozen_string_literal: true

module Supplejack
  class JobCompletionSummaryLogger
    def self.log_delete_worker_completion(exception:, record:, destination:, harvest_report:)
      source_id = record.dig('transformed_record', 'source_id') ||
                  harvest_report&.pipeline_job&.harvest_definitions&.first&.source_id ||
                  'unknown'
      extraction_name = record.dig('transformed_record', 'job_id') ||
                        harvest_report&.pipeline_job&.harvest_definitions&.first&.name ||
                        'unknown'

      log_completion(
        worker_class: 'DeleteWorker',
        exception: exception,
        extraction_id: source_id,
        extraction_name: extraction_name,
        details: {
          record: record,
          destination_id: destination.id,
          destination_name: destination.name,
          harvest_report_id: harvest_report&.id
        }
      )
    end

    def self.log_enrichment_extraction_completion(exception:, enrichment_params:)
      params = JSON.parse(enrichment_params)
      extraction_definition_id = params['extraction_definition_id']
      extraction_definition = ExtractionDefinition.find(extraction_definition_id)

      harvest_info = extract_harvest_info_from_definition(extraction_definition)
      return unless harvest_info

      log_completion(
        worker_class: 'EnrichmentExtractionWorker',
        exception: exception,
        extraction_id: harvest_info[:source_id],
        extraction_name: harvest_info[:name],
        details: {
          extraction_job_id: params['extraction_job_id'],
          extraction_definition_id: extraction_definition_id,
          harvest_job_id: params['harvest_job_id'],
          api_record: params['api_record'],
          page: params['page']
        }
      )
    end

    def self.log_file_extraction_completion(params)
      exception = params[:exception]
      extraction_definition = params[:extraction_definition]
      extraction_job = params[:extraction_job]
      extraction_folder = params[:extraction_folder]
      tmp_directory = params[:tmp_directory]

      harvest_info = extract_harvest_info_from_definition(extraction_definition)
      return unless harvest_info

      log_completion(
        worker_class: 'FileExtractionWorker',
        exception: exception,
        extraction_id: harvest_info[:source_id],
        extraction_name: harvest_info[:name],
        details: build_extraction_job_details(extraction_job, extraction_definition).merge(
          extraction_folder: extraction_folder,
          tmp_directory: tmp_directory
        )
      )
    end

    def self.log_load_worker_completion(params)
      exception = params[:exception]
      harvest_job = params[:harvest_job]
      harvest_report = params[:harvest_report]
      batch = params[:batch]
      api_record_id = params[:api_record_id]

      harvest_info = extract_harvest_info_from_job(harvest_job)
      return unless harvest_info

      log_completion(
        worker_class: 'LoadWorker',
        exception: exception,
        extraction_id: harvest_info[:source_id],
        extraction_name: harvest_info[:name],
        details: {
          harvest_job_id: harvest_job.id,
          harvest_report_id: harvest_report&.id,
          batch_size: batch&.size,
          api_record_id: api_record_id
        }
      )
    end

    def self.log_schedule_worker_completion(exception:, schedule:, error_context:)
      schedule_id = schedule.id
      schedule_name = schedule.name

      log_completion(
        worker_class: 'ScheduleWorker',
        exception: exception,
        extraction_id: "schedule_#{schedule_id}",
        extraction_name: "Schedule: #{schedule_name || 'Unnamed Schedule'}",
        message: "ScheduleWorker #{error_context} error: #{exception.class} - #{exception.message}",
        details: {
          schedule_id: schedule_id,
          schedule_name: schedule_name,
          error_context: error_context
        }
      )
    end

    def self.log_split_worker_completion(params)
      exception = params[:exception]
      extraction_definition = params[:extraction_definition]
      extraction_job = params[:extraction_job]
      folder = params[:folder]
      file = params[:file]

      harvest_info = extract_harvest_info_from_definition(extraction_definition)
      return unless harvest_info

      log_completion(
        worker_class: 'SplitWorker',
        exception: exception,
        extraction_id: harvest_info[:source_id],
        extraction_name: harvest_info[:name],
        details: build_extraction_job_details(extraction_job, extraction_definition).merge(
          folder: folder,
          file: file,
          split_selector: extraction_definition.split_selector
        )
      )
    end

    def self.log_text_extraction_completion(params)
      exception = params[:exception]
      extraction_definition = params[:extraction_definition]
      extraction_job = params[:extraction_job]
      folder = params[:folder]
      file = params[:file]

      harvest_info = extract_harvest_info_from_definition(extraction_definition)
      return unless harvest_info

      log_completion(
        worker_class: 'TextExtractionWorker',
        exception: exception,
        extraction_id: harvest_info[:source_id],
        extraction_name: harvest_info[:name],
        details: build_extraction_job_details(extraction_job, extraction_definition).merge(
          folder: folder,
          file: file,
          file_extension: file ? File.extname(file) : nil
        )
      )
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

    def self.log_error(
      extraction_id:,
      extraction_name:,
      message:,
      details: {}
    )
      JobCompletionSummary.log_completion(
        extraction_id: extraction_id,
        extraction_name: extraction_name,
        message: message,
        details: details
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log error to JobCompletionSummary: #{e.message}"
    end

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

    def self.resolve_message(message, worker_class, exception)
      message || "#{worker_class} error: #{exception.class} - #{exception.message}"
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

    def self.extract_harvest_info_from_definition(extraction_definition)
      harvest_definition = extraction_definition&.harvest_definition
      return nil unless harvest_definition&.source_id

      {
        source_id: harvest_definition.source_id,
        name: harvest_definition.name
      }
    end

    def self.extract_harvest_info_from_job(harvest_job)
      harvest_definition = harvest_job&.harvest_definition
      return nil unless harvest_definition&.source_id

      {
        source_id: harvest_definition.source_id,
        name: harvest_definition.name
      }
    end

    def self.build_extraction_job_details(extraction_job, extraction_definition)
      harvest_job = extraction_job.harvest_job
      {
        extraction_job_id: extraction_job.id,
        extraction_definition_id: extraction_definition.id,
        harvest_job_id: harvest_job&.id,
        harvest_report_id: harvest_job&.harvest_report&.id
      }
    end
  end
end
