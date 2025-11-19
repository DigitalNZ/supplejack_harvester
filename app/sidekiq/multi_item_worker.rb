# frozen_string_literal: true

class MultiItemWorker
  include PerformWithPriority
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(harvest_job_id)
    @harvest_job = HarvestJob.find(harvest_job_id)
    @pipeline_job = @harvest_job.pipeline_job
    
    # Find next step that needs multi-item extraction
    next_step = find_next_step_needing_multi_item
    return unless next_step
    
    # Get the extraction definition from next step
    extraction_definition = next_step.harvest_definitions.first.extraction_definition
    
    # Extract items from ALL ExtractionJobs in the current step
    items = extract_items_from_all_extraction_jobs(extraction_definition)
    
    return if items.empty?
    
    # Create new ExtractionJobs for next step
    create_extraction_jobs_for_items(items, next_step, extraction_definition)
  end

  private

  def find_next_step_needing_multi_item
    return nil unless @pipeline_job.from_automation?
    
    current_step = @pipeline_job.automation_step
    next_step = current_step.next_step
    return nil unless next_step
    
    # Check if next step has multi-item extraction enabled
    has_multi_item = next_step.harvest_definitions.any? do |harvest_def|
      extraction_def = harvest_def.extraction_definition
      # Check both new and old field names for backward compatibility
      (extraction_def.respond_to?(:multi_item_extraction_enabled?) && extraction_def.multi_item_extraction_enabled?) ||
      (extraction_def.respond_to?(:link_extraction_enabled?) && extraction_def.link_extraction_enabled?)
    end
    
    has_multi_item ? next_step : nil
  end

  def extract_items_from_all_extraction_jobs(extraction_definition)
    items = []
    
    # Get ALL ExtractionJobs from the current step's HarvestJob
    # Use all_extraction_jobs to get both old and new relationships
    @harvest_job.all_extraction_jobs.each do |extraction_job|
      extraction_job.documents.each do |document_path|
        document = Extraction::Document.load_from_file(document_path)
        next unless document.is_a?(Extraction::Document) && document.body.present?
        
        extracted_items = MultiItemExtractionService.extract_items_from_document(
          document, 
          extraction_definition
        )
        items.concat(extracted_items)
      end
    end
    
    items.uniq.compact
  end

  def create_extraction_jobs_for_items(items, next_step, extraction_definition)
    # Ensure next step has a PipelineJob
    next_pipeline_job = next_step.pipeline_job || create_pipeline_job_for_step(next_step)
    
    # Get or create HarvestJob for next step
    harvest_job = next_pipeline_job.harvest_jobs.first
    unless harvest_job
      harvest_definition = next_step.harvest_definitions.first
      harvest_job = HarvestJob.create(
        harvest_definition: harvest_definition,
        pipeline_job: next_pipeline_job,
        key: SecureRandom.hex(10)
      )
    end
    
    # Create HarvestReport if needed
    harvest_report = harvest_job.harvest_report || HarvestReport.create(
      pipeline_job: next_pipeline_job,
      harvest_job: harvest_job,
      kind: harvest_job.harvest_definition.kind,
      definition_name: harvest_job.harvest_definition.name
    )
    
    # Filter valid URLs
    valid_items = items.select { |item| !item.blank? && valid_item?(item) }
    
    # Create ExtractionJob for each item (all queued concurrently)
    valid_items.each do |item|
      temp_definition = create_temp_extraction_definition(extraction_definition, item)
      extraction_job = ExtractionJob.create(
        extraction_definition: temp_definition,
        harvest_job_id: harvest_job.id  # Use new relationship (harvest_job_id)
      )
      ExtractionWorker.perform_async_with_priority(
        next_pipeline_job.job_priority,
        extraction_job.id,
        harvest_report.id
      )
    end
  end

  def create_pipeline_job_for_step(step)
    # Create PipelineJob for the next step
    step.automation.create_pipeline_job(step)
  end

  def create_temp_extraction_definition(original_definition, item)
    temp_definition = original_definition.dup
    temp_definition.base_url = item  # Assume item is a URL
    temp_definition.name = "#{original_definition.name}_item_#{SecureRandom.hex(4)}"
    
    # Disable multi-item extraction on cloned definition to prevent recursion
    if temp_definition.respond_to?(:multi_item_extraction_enabled=)
      temp_definition.multi_item_extraction_enabled = false
    end
    if temp_definition.respond_to?(:link_extraction_enabled=)
      temp_definition.link_extraction_enabled = false
    end
    
    temp_definition.save!

    # Clone requests and parameters
    original_definition.requests.each do |request|
      cloned_request = request.dup
      cloned_request.extraction_definition = temp_definition
      cloned_request.save!

      request.parameters.each do |parameter|
        cloned_parameter = parameter.dup
        cloned_parameter.request = cloned_request
        cloned_parameter.save!
      end
    end

    temp_definition
  end

  def valid_item?(item)
    return false if item.blank?

    # Assume items are URLs for now
    uri = URI.parse(item)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end

