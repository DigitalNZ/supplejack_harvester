# frozen_string_literal: true

# The rows of the "Blocks to run" table, for one pipeline in one form.
#
# Holds what every row needs to know - the pipeline, whose form it is, and the
# current selection - so each RunBlockRow can be built from just its definition.
class RunBlocks
  # Only a schedule can be told to use the most recent pre-processed data: it is
  # resolved when the schedule fires, whereas a run happens now and names the run
  # it wants.
  SUBJECTS_OFFERED_LATEST = %w[schedule].freeze

  attr_reader :pipeline, :subject, :settings

  def initialize(pipeline:, subject:, settings:)
    @pipeline = pipeline
    @subject = subject
    @settings = settings
  end

  # The position-ordered pre-processing and harvest blocks: the chain, each of which
  # takes an input.
  def chain
    rows_for(pipeline.ordered_blocks)
  end

  # Enrichments are not part of the chain - they run after the harvest loads and
  # iterate records back out of the destination API, so there is no input to choose.
  def enrichments
    rows_for(pipeline.enrichments)
  end

  def offers_latest?
    subject.in?(SUBJECTS_OFFERED_LATEST)
  end

  private

  def rows_for(definitions)
    definitions.map { |definition| RunBlockRow.new(self, definition) }
  end
end
