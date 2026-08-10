# frozen_string_literal: true

class RequestsController < ApplicationController
  include LastEditedBy

  before_action :find_extraction_definition, only: %w[show]

  def show
    @request = Request.find(params[:id])

    return preprocess_request if preprocess_consumer?
    return harvest_request if @request.extraction_definition.harvest?

    enrichment_request
  end

  def update
    @request = Request.find(params[:id])

    if @request.update(request_params)
      update_last_edited_by([@request.extraction_definition])
      render json: @request.to_h
    else
      render500
    end
  end

  private

  def find_extraction_definition
    @extraction_definition = ExtractionDefinition.find(params[:extraction_definition_id])
  end

  def harvest_request
    if params[:previous_request_id].present?
      @previous_request = @extraction_definition.requests.find(params[:previous_request_id])

      @previous_response = Extraction::DocumentExtraction.new(@previous_request).extract
    end
    document = Extraction::DocumentExtraction.new(@request, nil, @previous_response).extract
    document.body = "Tar files can't be displayed" if @extraction_definition.format == 'ARCHIVE_JSON'

    render json: @request.to_h.merge(
      preview: document
    )
  end

  def enrichment_request
    parsed_body = JSON.parse(api_response.body)

    if @request.first_request?
      render json: first_enrichment_request_response(parsed_body)
    else
      render json: second_enrichment_request_response
    end
  end

  def page_param
    params[:page] || 1
  end

  def record_param
    params[:record] || 1
  end

  def api_response
    Extraction::RecordExtraction.new(@extraction_definition.requests.first, page_param).extract
  end

  def api_record
    Extraction::ApiResponse.new(api_response).record(record_param.to_i - 1)
  end

  def first_enrichment_request_response(parsed_body)
    @request.to_h.merge(preview: {
                          **api_record.to_hash,
                          **parsed_body['meta'],
                          total_records: parsed_body['records'].count
                        })
  end

  def second_enrichment_request_response
    @request.to_h.merge(preview: Extraction::EnrichmentExtraction.new(@request, api_record).extract)
  end

  def preprocess_consumer?
    @request.extraction_definition.harvest? && harvest_definition.position.to_i.positive?
  end

  def preprocess_request
    render json: @request.to_h.merge(preview: preprocess_preview)
  end

  def preprocess_preview
    runs = preprocess_runs
    return empty_preprocess_preview if runs.empty?

    build_preprocess_preview(chosen_run(runs), runs)
  end

  def build_preprocess_preview(run, runs)
    documents, records, input_record = preprocess_input(run)

    {
      input: input_record.to_hash,
      response: preprocess_response(input_record),
      total_pages: documents.total_pages,
      total_records: records.count,
      runs: runs.map { |job| { id: job.id, label: job.run_label } },
      current_run_id: run.id
    }
  end

  def preprocess_input(run)
    documents = PreProcess::Output.new(run.id, preceding_position).documents
    records = preprocess_page_records(documents)
    input_record = Extraction::ApiRecord.new(records[record_param.to_i - 1])

    [documents, records, input_record]
  end

  def empty_preprocess_preview
    { input: nil, response: nil, total_pages: 0, total_records: 0, runs: [], current_run_id: nil }
  end

  def preprocess_runs
    pipeline.runs_with_output_at(preceding_position).to_a
  end

  def chosen_run(runs)
    # Fall back to the most recent run when the requested pipeline_job_id isn't among this
    # position's runs (e.g. stale client state). Safe: runs is already pipeline-scoped.
    runs.find { |job| job.id == params[:pipeline_job_id].to_i } || runs.first
  end

  def preprocess_page_records(documents)
    document = documents[page_param]
    return [] unless document.is_a?(Extraction::Document)

    JSON.parse(document.body)['records'] || []
  rescue JSON::ParserError
    []
  end

  def preprocess_response(input_record)
    return {} if input_record.body.blank?

    document = Extraction::EnrichmentExtraction.new(@request, input_record).extract
    document.respond_to?(:to_hash) ? document.to_hash : {}
  end

  def preceding_position
    harvest_definition.position.to_i - 1
  end

  def pipeline
    @pipeline ||= Pipeline.find(params[:pipeline_id])
  end

  def harvest_definition
    @harvest_definition ||= HarvestDefinition.find(params[:harvest_definition_id])
  end

  def request_params
    params.expect(request: [:http_method])
  end
end
