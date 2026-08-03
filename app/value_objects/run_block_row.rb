# frozen_string_literal: true

# One row of the "Blocks to run" table: the block's labels, its form field names,
# and the inputs it can be given. Replaces the helper that built these, so that the
# Run modal and the schedule form share one description of a row.
class RunBlockRow
  include ActionView::Helpers::FormOptionsHelper

  TIME_FORMAT = '%-d %b %Y %H:%M'

  delegate :pipeline, :subject, :settings, :offers_latest?, to: :@blocks
  delegate :id, :source_id, :position, :enrichment?, :preprocess?, :ready_to_run?, to: :@definition

  def initialize(blocks, definition)
    @blocks = blocks
    @definition = definition
  end

  def label
    source_id
  end

  def kind_label
    preprocess? ? 'Pre-processing' : @definition.kind.humanize
  end

  def run?
    settings.run?(id)
  end

  def field_name(attribute)
    "#{subject}[block_settings][#{id}][#{attribute}]"
  end

  def field_id(attribute)
    "#{subject}_block_#{id}_#{attribute}"
  end

  # The block's own input first, then the reusable data grouped by what it is.
  # Grouping keeps the labels short enough to read inside a modal while still saying
  # what each option is.
  def input_options
    selected = settings.input_for(id).to_s

    options_for_select(default_options, selected) + grouped_options_for_select(reusable_groups, selected)
  end

  private

  def default_options
    return [['Fresh extraction', BlockInput::FRESH]] if position.zero?

    [['Output of previous block', BlockInput::FRESH]]
  end

  def reusable_groups
    {
      'Pre-processed data' => preprocess_output_options,
      'Existing extractions' => extraction_job_options
    }.reject { |_label, options| options.empty? }
  end

  def preprocess_output_options
    return [] if position.zero?

    latest_option + runs_with_output.map { |pipeline_job| stored_output_option(pipeline_job) }
  end

  def latest_option
    return [] unless offers_latest?

    [['Most recent', "#{BlockInput::PREPROCESS_OUTPUT}:#{BlockInput::LATEST}"]]
  end

  def stored_output_option(pipeline_job)
    ["Job ##{pipeline_job.id} · #{pipeline_job.created_at.strftime(TIME_FORMAT)}",
     "#{BlockInput::PREPROCESS_OUTPUT}:#{pipeline_job.id}"]
  end

  # The runs holding output for the position this block consumes.
  def runs_with_output
    pipeline.pipeline_jobs
            .where(id: PreProcess::Output.pipeline_job_ids_with_output(position - 1))
            .order(created_at: :desc)
  end

  def extraction_job_options
    extraction_jobs.map { |job| [job.name, "#{BlockInput::EXTRACTION_JOB}:#{job.id}"] }
  end

  def extraction_jobs
    @definition.extraction_definition&.extraction_jobs&.order(created_at: :desc) || []
  end
end
