# frozen_string_literal: true

# Builds the "Blocks to run" rows shared by the Run modal and the schedule form.
module RunBlocksHelper
  # The options HTML for one block's Input select: the block's default input first,
  # then the reusable data grouped by what it is. Grouping keeps the labels short
  # enough to read inside a modal while still saying what each option is.
  #
  # @param allow_latest [Boolean] offer "most recent pre-processed data", which is
  #   resolved when the run starts. Only makes sense for schedules - pinning a run
  #   id in a schedule would serve the same stale data every time it fires.
  def block_input_options(pipeline, definition, selected:, allow_latest: false)
    options_for_select(default_input_option(definition), selected) +
      grouped_options_for_select(reusable_input_groups(pipeline, definition, allow_latest:), selected)
  end

  def block_row_label(definition)
    return definition.source_id if definition.enrichment?

    "#{definition.position + 1}. #{definition.source_id}"
  end

  def block_kind_label(definition)
    definition.preprocess? ? 'Pre-processing' : definition.kind.humanize
  end

  private

  def default_input_option(definition)
    return [['Fresh extraction', BlockInput::FRESH]] if definition.position.zero?

    [['Output of previous block', BlockInput::FRESH]]
  end

  def reusable_input_groups(pipeline, definition, allow_latest:)
    groups = {}

    preprocess_outputs = preprocess_output_options(pipeline, definition, allow_latest:)
    groups['Pre-processed data'] = preprocess_outputs if preprocess_outputs.any?

    extraction_jobs = extraction_job_options(definition)
    groups['Existing extractions'] = extraction_jobs if extraction_jobs.any?

    groups
  end

  def preprocess_output_options(pipeline, definition, allow_latest:)
    return [] if definition.position.zero?

    options = allow_latest ? [['Most recent', "#{BlockInput::PREPROCESS_OUTPUT}:#{BlockInput::LATEST}"]] : []

    options + runs_with_output(pipeline, definition.position - 1).map do |pipeline_job|
      ["Job ##{pipeline_job.id} · #{pipeline_job.created_at.strftime('%-d %b %Y %H:%M')}",
       "#{BlockInput::PREPROCESS_OUTPUT}:#{pipeline_job.id}"]
    end
  end

  def runs_with_output(pipeline, position)
    pipeline.pipeline_jobs
            .where(id: PreProcess::Output.pipeline_job_ids_with_output(position))
            .order(created_at: :desc)
  end

  def extraction_job_options(definition)
    extraction_jobs = definition.extraction_definition&.extraction_jobs&.order(created_at: :desc) || []

    extraction_jobs.map do |extraction_job|
      [extraction_job.name, "#{BlockInput::EXTRACTION_JOB}:#{extraction_job.id}"]
    end
  end
end
