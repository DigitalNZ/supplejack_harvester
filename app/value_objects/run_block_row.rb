# frozen_string_literal: true

# One row of the "Blocks to run" table: the block's labels, its form field names,
# and the inputs it can be given. Replaces the helper that built these, so that the
# Run modal and the schedule form share one description of a row.
class RunBlockRow
  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::TagHelper

  delegate :pipeline, :subject, :settings, :offers_latest?, to: :@blocks
  delegate :id, :source_id, :position, :enrichment?, :preprocess?, :ready_to_run?,
           :configuration_problems, to: :@definition

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

  # Nothing at all when the block is fine, rather than an empty element, so the row does not
  # have to ask twice. Unnamed: it is rendered next to the block's own name. A disabled
  # checkbox on its own does not say what is wrong, and some of the reasons are a
  # disagreement between two definitions rather than something missing.
  def cannot_run_notice
    problems = configuration_problems
    return if problems.empty?

    tag.small("Cannot run: #{problems.to_sentence}.", class: 'd-block text-danger')
  end

  # nil renders an empty field, which reads as "all of them" next to the placeholder.
  def pages
    settings.pages_for(id)
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
    [pipeline_job.run_label, "#{BlockInput::PREPROCESS_OUTPUT}:#{pipeline_job.id}"]
  end

  # The runs holding output for the position this block consumes.
  def runs_with_output
    pipeline.runs_with_output_at(position - 1)
  end

  def extraction_job_options
    extraction_jobs.map { |job| [job.name, "#{BlockInput::EXTRACTION_JOB}:#{job.id}"] }
  end

  # Only jobs whose data is still on disk: a purged job has nothing to run against.
  def extraction_jobs
    @definition.available_extraction_jobs || []
  end
end
