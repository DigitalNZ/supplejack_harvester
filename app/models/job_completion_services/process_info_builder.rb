# frozen_string_literal: true

module JobCompletionServices
  class ProcessInfoBuilder
    def self.determine_process_info(definition)
      if definition.is_a?(ExtractionDefinition)
        build_extraction_process_info(definition)
      elsif definition.is_a?(TransformationDefinition)
        build_transformation_process_info(definition)
      else
        raise "Invalid definition type: #{definition.class.name}"
      end
    end

    def self.build_extraction_process_info(definition)
      definition.harvest_definitions.first
      {
        process_type: :extraction,
        job_type: 'ExtractionJob'
      }
    end

    def self.build_transformation_process_info(definition)
      definition.harvest_definitions.first
      {
        process_type: :transformation,
        job_type: 'TransformationJob'
      }
    end
  end
end
