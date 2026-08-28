# frozen_string_literal: true

module PipelineJobsHelper
  # The block's input as the Run modal draws it - a select holding the one choice this run
  # made - with a way through to the data itself beside it when the run named some and it
  # is still there. A disabled select cannot be a link, and where that data is is most of
  # what the row is worth reading for.
  def job_block_input_field(summary)
    label, path = job_block_input(summary)
    select = select_tag(nil, options_for_select([label]),
                        class: 'form-select form-select-sm', name: nil, id: nil)
    return select unless path

    tag.div(class: 'input-group input-group-sm') do
      safe_join([select, job_block_input_link(label, path)])
    end
  end

  private

  # What fed a block and where that data is, in the words the Run modal offers for the same
  # choice. A block left unticked took no input, and its own unticked box has already said
  # as much, so it answers with a dash. The path is nil unless the run named data of its own
  # and it is still there: data since purged leaves the words without a link rather than a
  # link that goes nowhere.
  def job_block_input(summary)
    return ['–', nil] unless summary.ran?
    return [summary.fresh_input_label, nil] if summary.input.fresh?

    reused_extraction(summary) || reused_preprocess_output(summary) || ['No longer available', nil]
  end

  # An input-group addon rather than a button: Bootstrap switches off pointer events on a
  # .btn inside a disabled fieldset, and the fieldset the job details wrap this in would
  # take the link with the fields it is there to disable.
  def job_block_input_link(label, path)
    link_to path, class: 'input-group-text', aria: { label: "View #{label}" } do
      tag.i(class: 'bi bi-box-arrow-up-right', aria: { hidden: true })
    end
  end

  def reused_extraction(summary)
    definition = summary.extraction_job_definition
    job = summary.extraction_job
    return unless job && definition

    [job.name, pipeline_harvest_definition_extraction_definition_extraction_job_path(
      summary.pipeline, definition, job.extraction_definition, job
    )]
  end

  def reused_preprocess_output(summary)
    source = summary.preprocess_source_job
    producer = summary.preprocess_producer
    return unless source && producer

    [source.run_label, pipeline_harvest_definition_preprocess_output_path(summary.pipeline, producer, source)]
  end
end
