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

    def determine_request_type
      if @harvest_definition.harvest?
        harvest_request
      elsif @harvest_definition.enrichment?
        enrichment_request
      end
    end

    def handle_response(response)
      Rails.logger.info "[LOAD] API Response - Status: #{response.status}, " \
                        "Body: #{response.body.inspect[0..500]}"

      # Check for server errors
      if response.status == 500
        raise StandardError, 'Destination API responded with status 500'
      end

      # Check for other error statuses (4xx, etc.)
      unless response.status >= 200 && response.status < 300
        Rails.logger.error "[LOAD] API returned non-success status: #{response.status}, " \
                           "Body: #{response.body.inspect[0..500]}"
        raise StandardError, "Destination API responded with status #{response.status}"
      end

      response
    end

    def handle_load_error(error)
      JobCompletionServices::ContextBuilder.create_job_completion_or_error({
                                                                             error: error,
                                                                             definition:
                                                                               @harvest_job&.extraction_definition,
                                                                             job: @harvest_job&.extraction_job,
                                                                             origin: 'LoadWorker'
                                                                           })
      raise
    end

    private

    def harvest_request
      records_to_send = build_records
      Rails.logger.info "[LOAD] Sending #{records_to_send.count} records to API " \
                        "(destination: #{@destination.url}, source_id: #{@harvest_definition.source_id})"

      response = Api::Harvester::Record.new(@destination).create_batch(
        records: records_to_send
      )

      Rails.logger.info "[LOAD] API request completed - Status: #{response.status}"
      response
    end

    def enrichment_request
      required_fragments = [@harvest_definition.source_id] if @harvest_definition.required_for_active_record?

      Api::Harvester::Fragment.new(@destination).post(
        @api_record_id,
        { fragment: build_record(@records.first), required_fragments: }
      )
    end

    def build_records
      built = @records.map { |record| { fields: build_record(record) } }
      Rails.logger.debug "[LOAD] Built #{built.count} records for API"
      built
    end

    def build_record(record)
      record = JSON.parse(record.to_json)['transformed_record']
      record.transform_values! { |value| [value].flatten(1) }

      record['source_id'] = @harvest_definition.source_id
      record['priority']  = @harvest_definition.priority
      record['job_id']    = @harvest_job.name

      record
    end

    def headers
      { 'Content-Type' => 'application/json' }
    end
  end
end
