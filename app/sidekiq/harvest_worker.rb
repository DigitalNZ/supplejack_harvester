# frozen_string_literal: true

class HarvestWorker < ApplicationWorker
  def child_perform(harvest_job)
    @harvest_job = harvest_job
    @pipeline_job = harvest_job.pipeline_job

    @harvest_report = HarvestReport.create(pipeline_job: @pipeline_job, harvest_job: @harvest_job,
                                           kind: @harvest_job.harvest_definition.kind,
                                           definition_name: @harvest_job.harvest_definition.name)

    if @pipeline_job.extraction_job.nil? || @harvest_job.harvest_definition.enrichment?
      create_extraction_job
    else
      create_transformation_jobs
    end
  end

  def create_extraction_job
    # Check if previous step was a pre-extraction step
    previous_pre_extraction_job_id = find_previous_pre_extraction_job_id

    extraction_job = ExtractionJob.create(
      extraction_definition: @harvest_job.extraction_definition,
      harvest_job: @harvest_job,
      pre_extraction_job_id: previous_pre_extraction_job_id,
      is_pre_extraction: false
    )

    ExtractionWorker.perform_async_with_priority(@pipeline_job.job_priority, extraction_job.id, @harvest_report.id)
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def create_transformation_jobs
    extraction_job = @pipeline_job.extraction_job
    @harvest_job.update(extraction_job_id: extraction_job.id)
    @harvest_report.extraction_completed!

    # Only create transformation jobs if they weren't already enqueued during extraction
    # This happens when extraction requires additional processing (split, extract_text_from_file)
    # OR when extraction didn't enqueue transformations (like pre-extraction jobs)
    if extraction_job.extraction_definition.split? || extraction_job.extraction_definition.extract_text_from_file?
      # Transformations weren't enqueued during extraction, so enqueue them now
      # Always start from page 1, not extraction_definition.page which might be wrong
      (1..extraction_job.documents.total_pages).each do |page|
        # Skip link documents - only transform actual content documents
        doc = extraction_job.documents[page]
        if doc.present? && is_link_document?(doc)
          Rails.logger.info "[HARVEST] Skipping transformation for page #{page} - this is a link document"
          next
        end
        
        @harvest_report.increment_pages_extracted!
        TransformationWorker.perform_in_with_priority(@pipeline_job.job_priority, (page * 5).seconds, @harvest_job.id,
                                                      page)
        @harvest_report.increment_transformation_workers_queued!

        @pipeline_job.reload
        break if @pipeline_job.cancelled? || page_number_reached?(page)
      end
    else
      # Transformations were already enqueued during extraction (for pre-extraction or normal extraction)
      Rails.logger.info "[HARVEST] Transformations were already enqueued during extraction, skipping create_transformation_jobs"
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  private

  def page_number_reached?(page)
    @pipeline_job.set_number? && page == @pipeline_job.pages
  end

  def find_previous_pre_extraction_job_id
    unless @harvest_job.pipeline_job.automation_step
      return nil
    end

    automation = @harvest_job.pipeline_job.automation_step.automation
    current_position = @harvest_job.pipeline_job.automation_step.position

    previous_pre_extraction_step = automation.automation_steps
                                             .where('position < ?', current_position)
                                             .where(step_type: 'pre_extraction')
                                             .order(position: :desc)
                                             .first

    if previous_pre_extraction_step
      previous_pre_extraction_step.pre_extraction_job_id
    else
      nil
    end
  end

  def is_link_document?(document)
    return false if document.nil?
    
    is_link_document_body?(document.body)
  end

  def is_link_document_body?(body)
    return false if body.nil?
    
    # If it's already a hash/object, check directly
    if body.is_a?(Hash)
      return body['pre_extraction_link'] == true || body[:pre_extraction_link] == true
    end
    
    # Convert to string for pattern matching
    body_str = body.to_s
    
    # Check if it contains the link blob pattern (works for any format)
    return true if body_str.include?('"pre_extraction_link":true') || body_str.include?("'pre_extraction_link':true")
    
    # Try to parse as JSON
    begin
      parsed = JSON.parse(body_str)
      return parsed['pre_extraction_link'] == true if parsed.is_a?(Hash)
    rescue JSON::ParserError
      # Not valid JSON, continue to HTML/XML check
    end
    
    # Try to extract JSON from HTML/XML
    begin
      # Check if it's HTML/XML that might contain JSON
      if body_str.strip.start_with?('<')
        # Try to find JSON within HTML/XML tags
        # Look for JSON pattern in text content
        if body_str.match(/\{"url":.*"pre_extraction_link":\s*true\}/)
          return true
        end
        
        # Try parsing as HTML/XML and extracting text
        doc = Nokogiri::HTML.parse(body_str) rescue Nokogiri::XML.parse(body_str)
        text_content = doc.text.strip
        
        # Try parsing the extracted text as JSON
        if text_content.start_with?('{')
          parsed = JSON.parse(text_content)
          return parsed['pre_extraction_link'] == true if parsed.is_a?(Hash)
        end
      end
    rescue Nokogiri::SyntaxError, JSON::ParserError
      # Not HTML/XML or JSON extraction failed
    end
    
    false
  end
end
