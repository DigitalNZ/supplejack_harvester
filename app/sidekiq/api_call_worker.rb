# frozen_string_literal: true

class ApiCallWorker
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(automation_step_id)
    @automation_step = AutomationStep.find(automation_step_id)
    execute_api_call
  end

  private

  def execute_api_call
    begin
      uri = URI.parse(@automation_step.api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      
      # Create the request based on the method
      request = create_request(uri)
      
      # Set headers
      if @automation_step.api_headers.present?
        JSON.parse(@automation_step.api_headers).each do |key, value|
          request[key] = value
        end
      end
      # Set the request body for methods that support it
      if %w[POST PUT PATCH].include?(@automation_step.api_method) && @automation_step.api_body.present?
        # Interpolate variables in the API body
        # TODO: improve this
        request.body = interpolate_variables(@automation_step.api_body)
      end
      
      # Execute the request
      response = http.request(request)
      
      # Create or update the API response report
      create_or_update_api_response_report(response)
      
      # Return true if the response was successful (2xx status code)
      response.is_a?(Net::HTTPSuccess)
    rescue => e
      create_or_update_api_response_report_with_error(e)
      false
    end
  end

  def create_request(uri)
    case @automation_step.api_method
    when 'GET'
      Net::HTTP::Get.new(uri.request_uri)
    when 'POST'
      Net::HTTP::Post.new(uri.request_uri)
    when 'PUT'
      Net::HTTP::Put.new(uri.request_uri)
    when 'PATCH'
      Net::HTTP::Patch.new(uri.request_uri)
    when 'DELETE'
      Net::HTTP::Delete.new(uri.request_uri)
    else
      raise "Unsupported HTTP method: #{@automation_step.api_method}"
    end
  end

  def interpolate_variables(body)
    return body unless body.is_a?(String)
    
    # Try to parse as JSON first
    begin
      # Parse the body into a hash
      body_hash = JSON.parse(body)
      
      # Deep traverse the hash and replace any {{job_ids}} placeholders
      traverse_and_replace(body_hash)
      
      # Convert back to JSON
      return body_hash.to_json
    rescue JSON::ParserError
      # If not valid JSON, fall back to string replacement
      job_ids = collect_pipeline_job_ids
      body.gsub(/\{\{job_ids\}\}/, job_ids.to_json)
    end
  end

  def traverse_and_replace(obj)
    case obj
    when Hash
      obj.each { |k, v| obj[k] = traverse_and_replace(v) }
    when Array
      obj.map! { |v| traverse_and_replace(v) }
    when String
      if obj.include?('{{job_ids}}')
        job_ids = collect_pipeline_job_ids
        obj.gsub('{{job_ids}}', job_ids.to_json)
      else
        obj
      end
    else
      obj
    end
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
    
    if @automation_step.api_response_report.present?
      @automation_step.api_response_report.update(report_attributes)
    else
      @automation_step.create_api_response_report(report_attributes)
    end
  end

  def create_or_update_api_response_report_with_error(error)
    report_attributes = {
      status: 'errored',
      response_code: nil,
      response_body: "Error: #{error.message}",
      response_headers: nil,
      executed_at: Time.current
    }
    
    if @automation_step.api_response_report.present?
      @automation_step.api_response_report.update(report_attributes)
    else
      @automation_step.create_api_response_report(report_attributes)
    end
  end
end 