# frozen_string_literal: true

module Load
  class Execution
    # Non-2xx statuses worth asking again about: a destination that is overloaded, restarting
    # or rate limiting will take the same batch later. One that called the batch malformed,
    # too large or unauthorised will not, and a redirect reaching here is a destination URL
    # that needs fixing rather than retrying.
    TRANSIENT_STATUSES = [408, 429, *500..599].freeze

    def initialize(records, harvest_job, api_record_id = nil)
      @records            = records
      @harvest_job        = harvest_job
      @destination        = harvest_job.pipeline_job.destination
      @harvest_definition = harvest_job.harvest_definition
      @api_record_id      = api_record_id
    end

    # Errors are left to travel to LoadWorker rather than being recorded here. Recording
    # them here meant every attempt Retriable went on to retry successfully still left a
    # JobError behind, so the load errors on a run said nothing about whether any records
    # were actually lost - two thirds of them were recoveries. LoadWorker records the one
    # that matters, once the retries are spent.
    def call
      response = determine_request_type
      handle_response(response)
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
      else raise PermanentError, "a #{@harvest_definition.load_kind} definition cannot be loaded"
      end
    end

    # Only a 2xx means the batch landed. Anything else counted as a success unless it was
    # exactly 500, so a 502/503/504 from a proxy in front of a struggling destination, or a
    # 413 refusing an oversized batch, had its records counted as loaded and left no trace at
    # all - no error recorded, and a report that balanced. Api::Request carries no
    # raise_error middleware, so the status has to be read here rather than arriving as an
    # exception.
    def handle_response(response)
      return response if response.success?

      status = response.status
      message = "Destination API responded with status #{status}"
      raise PermanentError, message unless TRANSIENT_STATUSES.include?(status)

      raise StandardError, message
    end

    private

    # The timeout comes from the load definition so a source whose batches are slow to write can
    # wait longer without every other destination call in the app waiting with it.
    def harvest_request
      Api::Harvester::Record.new(@destination, read_timeout:).create_batch(
        records: build_records
      )
    end

    def enrichment_request
      required_fragments = [@harvest_definition.source_id] if @harvest_definition.load_required_for_active_record?

      Api::Harvester::Fragment.new(@destination, read_timeout:).post(
        @api_record_id,
        { fragment: build_record(@records.first), required_fragments: }
      )
    end

    def read_timeout = @harvest_definition.load_read_timeout

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
