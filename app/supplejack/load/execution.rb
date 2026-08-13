# frozen_string_literal: true

module Load
  class Execution
    def initialize(records, harvest_job, api_record_id = nil)
      @records            = records
      @harvest_job        = harvest_job
      @destination        = harvest_job.pipeline_job.destination
      @harvest_definition = harvest_job.harvest_definition
      @api_record_id      = api_record_id
    end

    def call
      response = determine_request_type
      handle_response(response)
    rescue StandardError => e
      handle_load_error(e)
    end

    # Which fragment of the destination record this block writes decides how it is
    # addressed. Both fragment kinds go through create_batch, which finds the record by
    # internal_identifier and picks the fragment by priority; an enrichment already holds
    # the record's id, so it posts straight to that record's fragments. A block writing to
    # disk feeds the next block and never reaches the load stage, so it can only be a
    # misconfiguration here - raise rather than returning nil, which handle_response turns
    # into a NoMethodError on #status.
    def determine_request_type
      case @harvest_definition.load_kind
      when 'primary_fragment', 'secondary_fragment' then harvest_request
      when 'enrichment' then enrichment_request
      else raise StandardError, "a #{@harvest_definition.load_kind} definition cannot be loaded"
      end
    end

    def handle_response(response)
      return response unless response.status == 500

      raise StandardError, 'Destination API responded with status 500'
    end

    def handle_load_error(error)
      JobCompletionServices::ContextBuilder.create_job_completion_or_error(
        {
          error: error,
          definition:
          @harvest_job&.extraction_definition,
          job: @harvest_job&.extraction_job,
          origin: 'LoadWorker'
        }
      )
      raise
    end

    private

    def harvest_request
      Api::Harvester::Record.new(@destination).create_batch(
        records: build_records
      )
    end

    def enrichment_request
      required_fragments = [@harvest_definition.source_id] if @harvest_definition.load_required_for_active_record?

      Api::Harvester::Fragment.new(@destination).post(
        @api_record_id,
        { fragment: build_record(@records.first), required_fragments: }
      )
    end

    def build_records
      @records.map { |record| { fields: build_record(record) } }
    end

    def build_record(record)
      record = JSON.parse(record.to_json)['transformed_record']
      record.transform_values! { |value| [value].flatten(1) }

      record['source_id'] = @harvest_definition.source_id
      record['priority']  = @harvest_definition.load_priority
      record['job_id']    = @harvest_job.name

      record
    end

    def headers
      { 'Content-Type' => 'application/json' }
    end
  end
end
