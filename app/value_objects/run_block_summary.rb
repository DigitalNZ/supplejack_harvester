# frozen_string_literal: true

# One block of a run, as the job details page reads it: whether the job was asked to run
# it, what fed it, and how much of it it was told to process.
#
# The read-only mirror of RunBlockRow, which asks those same three questions in the Run
# modal and the schedule form. Every job can answer them however it was started - a job
# that posted none of this, which is nearly all of them and everything the API and
# automation paths still create, has its answers rebuilt from the flat fields by
# RunConfiguration#run_settings.
class RunBlockSummary
  # In the order the Run modal lists them: the chain by position, then the enrichments,
  # which run after the harvest has loaded and so are not part of it.
  def self.for(pipeline_job)
    pipeline = pipeline_job.pipeline

    (pipeline.ordered_blocks + pipeline.enrichments).map { |definition| new(pipeline_job, definition) }
  end

  delegate :id, :source_id, :position, :enrichment?, :preprocess?, :preceding_position, to: :@definition
  delegate :pipeline, to: :@pipeline_job

  def initialize(pipeline_job, definition)
    @pipeline_job = pipeline_job
    @definition = definition
  end

  def label = source_id

  def kind_label = preprocess? ? 'Pre-processing' : @definition.kind.humanize

  # The job's own answer rather than its run settings', because it is the one the workers
  # asked before running anything.
  def ran? = @pipeline_job.should_run?(@definition.id)

  # Read through the job rather than through its run settings: only the job folds in a
  # limit posted as the job-wide page_type/pages, which is the only limit a run created
  # before the modal grew a Pages column can have.
  def pages = @pipeline_job.pages_for(@definition)

  def input = @pipeline_job.input_for(@definition)

  # The page limit as the modal's own Pages field carries it: the number this block was
  # given, and nothing at all for a block that did not run.
  def pages_field
    pages if ran?
  end

  # An empty field reads as every page against the modal's placeholder, which is the answer
  # for a block that ran without a limit and a lie for one that never ran - so the
  # placeholder goes with it, leaving the field saying nothing rather than saying "all".
  def pages_placeholder
    'All pages' if ran?
  end

  # Position 0 has nothing before it to take an input from, so running fresh there is an
  # extraction; anywhere else it is whatever the preceding block fed forward.
  def fresh_input_label = position.zero? ? 'Fresh extraction' : 'Output of previous block'

  # The extraction whose documents this block transformed rather than extracting afresh.
  # Nil once that job has been purged, which is a thing the page has to be able to say.
  def extraction_job
    return unless input.extraction_job?

    ExtractionJob.find_by(id: input.extraction_job_id)
  end

  # The run whose pre-processed data fed this block. A schedule may have asked for
  # whichever was most recent, and that is copied onto the job unresolved - so the answer
  # comes from the extraction job, which records the run it actually read.
  def preprocess_source_job
    return unless input.preprocess_output?

    PipelineJob.find_by(id: input.pipeline_job_id || resolved_source_job_id)
  end

  # The block that wrote that data. PreprocessOutputsController reads the output by the
  # position of the definition in its path, so the link needs the producer rather than
  # this block, which is the one consuming it.
  def preprocess_producer
    pipeline.ordered_blocks.find_by(position: preceding_position)
  end

  # The block a reused extraction is addressed through, which is not necessarily this one:
  # a run can be pointed at an extraction some other block made.
  def extraction_job_definition
    job = extraction_job
    return unless job

    definition = job.extraction_definition

    job.harvest_job&.harvest_definition ||
      pipeline.harvest_definitions.find_by(extraction_definition: definition) ||
      definition.harvest_definitions.first
  end

  private

  def resolved_source_job_id
    harvest_job&.extraction_job&.source_pipeline_job_id
  end

  def harvest_job
    @pipeline_job.harvest_jobs.find_by(harvest_definition_id: @definition.id)
  end
end
