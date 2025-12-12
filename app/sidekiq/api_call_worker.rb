# frozen_string_literal: true

class ApiCallWorker
  include PerformWithPriority
  include Sidekiq::Job
  include ApiUtilities

  sidekiq_options retry: 0

  def perform(automation_step_id)
    @automation_step = AutomationStep.find(automation_step_id)
    execute_api_call
  end

  private

  def execute_api_call
    uri = URI.parse(@automation_step.api_url)
    http = setup_http_client(uri)

    # Create the request based on the method
    request = create_request(uri)

    # Prepare the request with headers and body
    prepare_request(request)

    # Execute the request
    execute_request_and_handle_response(http, request)
  end

  def prepare_request(request)
    add_request_headers(request, @automation_step.api_headers)
    add_request_body(request)
  end

  def add_request_body(request)
    api_body = @automation_step.api_body
    return unless %w[POST PUT PATCH].include?(@automation_step.api_method) && api_body.present?

    # Interpolate variables in the API body
    request.body = interpolate_variables(api_body)
  end

  def execute_request_and_handle_response(http, request)
    # Execute the request
    response = http.request(request)

    # Create or update the API response report
    create_or_update_api_response_report(response)

    # Return true if the response was successful (2xx status code)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    create_or_update_api_response_report_with_error(e)
    false
  end

  def create_request(uri)
    request_class = request_class_for_method(@automation_step.api_method)
    request_class.new(uri.request_uri)
  end

  def collect_pipeline_job_ids
    # Get all automation steps with pipeline jobs up to this step
    pipeline_steps = @automation_step.automation.automation_steps
                                     .where(step_type: 'pipeline')
                                     .where('position < ?', @automation_step.position)
                                     .includes(:pipeline_job)
                                     .order(position: :asc)

    # Extract the job names instead of IDs
    pipeline_steps.flat_map do |step|
      step.pipeline_job&.harvest_jobs&.map(&:name)
    end.compact
  end

  def create_or_update_api_response_report(response)
    report_attributes = {
      status: response.is_a?(Net::HTTPSuccess) ? 'completed' : 'errored',
      response_code: response.code,
      response_body: response.body.to_s.truncate(8000),
      response_headers: response.to_hash.to_json,
      executed_at: Time.current
    }

    update_or_create_report(report_attributes)
  end

  def create_or_update_api_response_report_with_error(error)
    report_attributes = {
      status: 'errored',
      response_code: nil,
      response_body: "Error: #{error.message}",
      response_headers: nil,
      executed_at: Time.current
    }

    update_or_create_report(report_attributes)
  end

  def update_or_create_report(attributes)
    existing_report = @automation_step.api_response_report
    if existing_report.present?
      existing_report.update(attributes)
    else
      @automation_step.create_api_response_report(attributes)
    end
  end
end
