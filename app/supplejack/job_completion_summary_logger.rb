# frozen_string_literal: true

module Supplejack
  class JobCompletionSummaryLogger

    def self.log_completion(args)

      context = build_context_from_args(args)

      JobCompletionSummary.log_completion(context)
    rescue StandardError => e
      Rails.logger.error "Failed to log completion to JobCompletionSummary: #{e.message}"
    end


  def self.build_context_from_args(args)
    error = args[:error]
    definition = args[:definition]
    job = args[:job] # source id, source name, 
    details = args[:details] || {}
  
    is_stop_condition? = details[:stop_condition_name].present? # stop condtition details, 

    extraction_definition = definition.is_a?(ExtractionDefinition)
    transformation_definition = definition.is_a?(TransformationDefinition)

    # Determine process type and job type based on what's present
    if extraction_definition
      process_type = :extraction
      job_type = 'ExtractionJob'
      harvest_definition = definition.harvest_definitions.first
      source_id = harvest_definition&.source_id || 'unknown'
      source_name = harvest_definition&.name || 'unknown'
      worker_class = 'Extraction::Execution'
    elsif transformation_definition
      process_type = :transformation
      job_type = 'TransformationJob'
      harvest_definition = definition.harvest_definitions.first
      source_id = harvest_definition&.source_id || 'unknown'
      source_name = harvest_definition&.name || 'unknown'
      worker_class = 'Transformation::Execution'
    else
      raise "Invalid definition type: #{definition.class.name}"
    end

    # Determine completion type
    completion_type = if is_stop_condition?
                        :stop_condition
                      else
                        :error # fallback
                      end

    # stop condition message
    if is_stop_condition?
      message = if details[:stop_condition_type] != 'user'
        "System stop condition '#{details[:stop_condition_name]}' was triggered"
      else
        "Stop condition '#{details[:stop_condition_name]}' was triggered"
      end
    else
      message = error ? "#{error.class.name}: #{error.message}" : "Unknown error occurred"
    end

    enhanced_details = {}

    # Add error details if present
    if error
      enhanced_details.merge!(
        exception_class: error.class.name,
        exception_message: error.message,
        stack_trace: error.backtrace&.first(20)
      )
    end

    # Add job IDs
    enhanced_details[:job_id] = job&.id

    # Add stop condition details if present
    if details[:stop_condition_name].present?
      enhanced_details.merge!(
        stop_condition_name: details[:stop_condition_name],
        stop_condition_content: details[:stop_condition_content],
        stop_condition_type: details[:stop_condition_type]
      )
    end

    # Merge any additional details
    enhanced_details.merge!(details.except(:stop_condition_name, :stop_condition_content, :stop_condition_type))

    # context to pass to model for completion summary
    {
      source_id: source_id,
      source_name: source_name,
      process_type: process_type,
      job_type: job_type,
      completion_type: completion_type,
      message: message,
      details: enhanced_details
    }
  end
end
