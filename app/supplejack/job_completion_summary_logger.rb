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
      extraction_definition = ExtractionDefinition.find(params['extraction_definition_id'])

      return unless extraction_definition&.harvest_definition&.source_id

      log_completion(
        worker_class: 'EnrichmentExtractionWorker',
        exception: exception,
        extraction_id: extraction_definition.harvest_definition.source_id,
        extraction_name: extraction_definition.harvest_definition.name,
        details: {
          extraction_job_id: params['extraction_job_id'],
          extraction_definition_id: params['extraction_definition_id'],
          harvest_job_id: params['harvest_job_id'],
          api_record: params['api_record'],
          page: params['page']
        }
      )
    end

    def self.log_file_extraction_completion(exception:, extraction_definition:, extraction_job:, extraction_folder:, tmp_directory:)
      return unless extraction_definition&.harvest_definition&.source_id

      log_completion(
        worker_class: 'FileExtractionWorker',
        exception: exception,
        extraction_id: extraction_definition.harvest_definition.source_id,
        extraction_name: extraction_definition.harvest_definition.name,
        details: {
          extraction_job_id: extraction_job.id,
          extraction_definition_id: extraction_definition.id,
          harvest_job_id: extraction_job.harvest_job&.id,
          harvest_report_id: extraction_job.harvest_job&.harvest_report&.id,
          extraction_folder: extraction_folder,
          tmp_directory: tmp_directory
        }
      )
    end

    def self.log_load_worker_completion(exception:, harvest_job:, harvest_report:, batch:, api_record_id:)
      return unless harvest_job&.harvest_definition&.source_id

      log_completion(
        worker_class: 'LoadWorker',
        exception: exception,
        extraction_id: harvest_job.harvest_definition.source_id,
        extraction_name: harvest_job.harvest_definition.name,
        details: {
          harvest_job_id: harvest_job.id,
          harvest_report_id: harvest_report&.id,
          batch_size: batch&.size,
          api_record_id: api_record_id
        }
      )
    end

    def self.log_schedule_worker_completion(exception:, schedule:, error_context:)
      log_completion(
        worker_class: 'ScheduleWorker',
        exception: exception,
        extraction_id: "schedule_#{schedule.id}",
        extraction_name: "Schedule: #{schedule.name || 'Unnamed Schedule'}",
        message: "ScheduleWorker #{error_context} error: #{exception.class} - #{exception.message}",
        details: {
          schedule_id: schedule.id,
          schedule_name: schedule.name,
          error_context: error_context
        }
      )
    end

    def self.log_split_worker_completion(exception:, extraction_definition:, extraction_job:, folder:, file:)
      return unless extraction_definition&.harvest_definition&.source_id

      log_completion(
        worker_class: 'SplitWorker',
        exception: exception,
        extraction_id: extraction_definition.harvest_definition.source_id,
        extraction_name: extraction_definition.harvest_definition.name,
        details: {
          extraction_job_id: extraction_job.id,
          extraction_definition_id: extraction_definition.id,
          harvest_job_id: extraction_job.harvest_job&.id,
          harvest_report_id: extraction_job.harvest_job&.harvest_report&.id,
          folder: folder,
          file: file,
          split_selector: extraction_definition.split_selector
        }
      )
    end

    def self.log_text_extraction_completion(exception:, extraction_definition:, extraction_job:, folder:, file:)
      return unless extraction_definition&.harvest_definition&.source_id

      log_completion(
        worker_class: 'TextExtractionWorker',
        exception: exception,
        extraction_id: extraction_definition.harvest_definition.source_id,
        extraction_name: extraction_definition.harvest_definition.name,
        details: {
          extraction_job_id: extraction_job.id,
          extraction_definition_id: extraction_definition.id,
          harvest_job_id: extraction_job.harvest_job&.id,
          harvest_report_id: extraction_job.harvest_job&.harvest_report&.id,
          folder: folder,
          file: file,
          file_extension: File.extname(file)
        }
      )
    end

    def self.log_stop_condition_hit(
      extraction_definition:,
      stop_condition_name:,
      stop_condition_content:,
      extraction_job: nil,
      harvest_job: nil,
      document: nil,
      additional_details: {}
    )
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

    private

    def self.log_completion(worker_class:, exception:, extraction_id:, extraction_name:, details: {}, message: nil)
      JobCompletionSummary.log_completion(
        extraction_id: extraction_id,
        extraction_name: extraction_name,
        message: message || "#{worker_class} error: #{exception.class} - #{exception.message}",
        details: build_completion_details(worker_class, exception, details)
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log #{worker_class.downcase} completion to JobCompletionSummary: #{e.message}"
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
  end
end
