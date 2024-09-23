# frozen_string_literal: true

class RequestsController < ApplicationController
  include LastEditedBy

  before_action :find_extraction_definition, only: %w[show]

  def show
    @request = Request.find(params[:id])

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

  def request_params
    params.require(:request).permit(:http_method)
  end
end
