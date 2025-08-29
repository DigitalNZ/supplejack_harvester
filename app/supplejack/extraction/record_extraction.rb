# frozen_string_literal: true

module Extraction
  class RecordExtraction < AbstractExtraction
    def initialize(request, page, harvest_job = nil)
      super()
      @request               = request
      @extraction_definition = request.extraction_definition
      @page                  = page
      @harvest_job           = harvest_job
    end

    private

    def url
      "#{api_source.url}/harvester/records"
    end

    def params
      {
        search: active_filter.merge(fragment_filter),
        search_options: { page: @page },
        api_key: api_source.api_key
      }.merge(
        extraction_definition_fields,
        record_includes,
        exclude_source_id
      )
    end

    def extraction_definition_fields
      fields = @extraction_definition.fields
      return { fields: fields.split(',').map(&:squish) } if fields.present?

      {}
    end

    def record_includes
      return {} if @extraction_definition.include_sub_documents?

      { record_includes: 'null' }
    end

    def active_filter
      { status: :active }
    end

    def exclude_source_id
      return {} unless @extraction_definition.incremental?

      { exclude_source_id: @harvest_job.harvest_definition.source_id }
    end

    def fragment_filter
      return target_job_fragment_filter if target_job?
      return automation_step_fragment_filter if automation_step?

      source_fragment_filter
    end

    def target_job?
      @harvest_job&.target_job_id.present?
    end

    def target_job_fragment_filter
      { 'fragments.job_id' => @harvest_job.target_job_id }
    end

    def automation_step?
      @harvest_job&.pipeline_job&.automation_step.present?
    end

    def automation_step_fragment_filter
      job_names = automation_step_job_names
      { 'fragments.job_id' => job_names }
    end

    def automation_step_job_names
      @harvest_job.pipeline_job.automation_step.automation.automation_steps
                  .filter_map(&:pipeline_job)
                  .flat_map(&:harvest_jobs)
                  .map(&:name)
                  .select { |name| name.include?('__harvest-') }
    end

    def source_fragment_filter
      { 'fragments.source_id' => @extraction_definition.source_id }
    end

    def api_source
      return @harvest_job.pipeline_job.destination if @harvest_job.present?

      @extraction_definition.destination
    end
  end
end
