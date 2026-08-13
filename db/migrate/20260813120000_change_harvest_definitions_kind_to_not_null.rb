# frozen_string_literal: true

class ChangeHarvestDefinitionsKindToNotNull < ActiveRecord::Migration[8.0]
  # A block with no kind cannot be run - see the kind validation on HarvestDefinition for
  # what happens when one is. The validation stops new ones; this stops the column holding
  # them at all.
  #
  # Any left are backfilled to preprocess (2) rather than the column's default of harvest
  # (0). A pre-processing block writes to disk for the next block to read: it cannot post
  # records to a destination and cannot flush anything, so a wrong guess leaves the block
  # doing nothing anyone has to undo. Guessing harvest would have it write records under its
  # source_id, which is a great deal harder to take back than a wrong label on a block.
  #
  # The ids are logged, because the guess is a guess and whoever deploys this should be able
  # to go and set the right kind afterwards.
  def up
    backfill_missing_kinds

    change_column_null :harvest_definitions, :kind, false
  end

  # Which rows were null cannot be recovered, so this only relaxes the constraint.
  def down
    change_column_null :harvest_definitions, :kind, true
  end

  private

  def backfill_missing_kinds
    ids = select_values('SELECT id FROM harvest_definitions WHERE kind IS NULL')
    return say('no harvest definitions are missing a kind') if ids.empty?

    say("setting kind to preprocess on #{ids.size} definition(s) with none: #{ids.join(', ')}")
    execute('UPDATE harvest_definitions SET kind = 2 WHERE kind IS NULL')
  end
end
