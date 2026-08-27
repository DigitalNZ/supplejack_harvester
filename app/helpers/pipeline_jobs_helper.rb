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
    return select if path.nil?

    tag.div(class: 'input-group input-group-sm') do
      safe_join([select, job_block_input_link(label, path)])
    end
  end

  # A dash where there is no setting to report: a block left unticked took no input, and
  # its own unticked box has already said as much.
  def job_block_pages(summary)
    summary.pages if summary.ran?
  end

  # An empty field reads as every page against the modal's placeholder, which is the answer
  # for a block that ran without a limit and a lie for one that did not run at all - so the
  # placeholder goes with it, leaving the field saying nothing rather than saying "all".
  def job_block_pages_placeholder(summary)
    'All pages' if summary.ran?
  end

  # The words the schedule form's own Yes/No selects offer, so a setting reads the same
  # whether it is being chosen or read back.
  def job_yes_no(setting)
    setting ? 'Yes' : 'No'
  end

  private

  # What fed a block and where that data is, in the words the Run modal offers for the same
  # choice. The path is nil unless the run named data of its own and it is still there:
  # data since purged leaves the words without a link rather than a link that goes nowhere.
  def job_block_input(summary)
    return ['–', nil] unless summary.ran?
    return [fresh_input_label(summary), nil] if summary.input.fresh?

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

  # Position 0 has nothing before it to take an input from, so running fresh there is an
  # extraction; anywhere else it is whatever the preceding block fed forward.
  def fresh_input_label(summary)
    summary.position.zero? ? 'Fresh extraction' : 'Output of previous block'
  end

  def reused_extraction(summary)
    extraction_job = summary.extraction_job
    definition = summary.extraction_job_definition
    return if extraction_job.nil? || definition.nil?

    [extraction_job.name, pipeline_harvest_definition_extraction_definition_extraction_job_path(
      summary.pipeline, definition, extraction_job.extraction_definition, extraction_job
    )]
  end

  def reused_preprocess_output(summary)
    source = summary.preprocess_source_job
    producer = summary.preprocess_producer
    return if source.nil? || producer.nil?

    [source.run_label, pipeline_harvest_definition_preprocess_output_path(summary.pipeline, producer, source)]
  end
end
