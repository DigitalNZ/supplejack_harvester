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
        api_key: api_source.api_key,
        record_includes: 
    }.merge(
      if @extraction_definition.fields.present?
        {
          fields: @extraction_definition.fields.split(','),
        }
      else
        {}
      end
    )
    end

    def record_includes
      return [] if @extraction_definition.include_sub_documents?

      'null'
    end

    def active_filter
      { status: :active }
    end

    def fragment_filter
      if @harvest_job&.target_job_id.present?
        { 'fragments.job_id' => @harvest_job.target_job_id }
      else
        { 'fragments.source_id' => @extraction_definition.source_id }
      end
    end

    def api_source
      return @harvest_job.pipeline_job.destination if @harvest_job.present?

      @extraction_definition.destination
    end
  end
end
