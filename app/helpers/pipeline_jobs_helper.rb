# frozen_string_literal: true

module PipelineJobsHelper
  # What fed a block, in the words the Run modal offers for the same choice, and linked to
  # the data itself when the run named some. Data since purged leaves the words without a
  # link rather than a link that goes nowhere.
  def job_block_input(summary)
    return 'Harvested records' if summary.enrichment?
    return fresh_input_label(summary) if summary.input.fresh?

    extraction_job_link(summary) || preprocess_output_link(summary) || 'No longer available'
  end

  # A dash where there is no setting to report rather than a count: a block left unticked
  # processed nothing, and an enrichment is never offered a page limit - the Run modal
  # gives its row neither an input nor a Pages field.
  def job_block_pages(summary)
    return '–' if !summary.ran? || summary.enrichment?

    summary.pages || 'All'
  end

  private

  # Position 0 has nothing before it to take an input from, so running fresh there is an
  # extraction; anywhere else it is whatever the preceding block fed forward.
  def fresh_input_label(summary)
    summary.position.zero? ? 'Fresh extraction' : 'Output of previous block'
  end

  def extraction_job_link(summary)
    extraction_job = summary.extraction_job
    definition = summary.extraction_job_definition
    return if extraction_job.nil? || definition.nil?

    link_to extraction_job.name, pipeline_harvest_definition_extraction_definition_extraction_job_path(
      summary.pipeline, definition, extraction_job.extraction_definition, extraction_job
    )
  end

  def preprocess_output_link(summary)
    source = summary.preprocess_source_job
    producer = summary.preprocess_producer
    return if source.nil? || producer.nil?

    link_to source.run_label, pipeline_harvest_definition_preprocess_output_path(summary.pipeline, producer, source)
  end
end
