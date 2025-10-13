class FixJobCompletionSummaryProcessTypeNilValues < ActiveRecord::Migration[7.2]
  def up
    # Update any nil process_type values to default to extraction (0)
    execute <<-SQL
      UPDATE job_completion_summaries 
      SET process_type = 0 
      WHERE process_type IS NULL
    SQL

    # Ensure the column is not null going forward
    change_column_null :job_completion_summaries, :process_type, false
  end

  def down
    # This migration is not easily reversible since we're changing nil to 0
    # But we can make the column nullable again if needed
    change_column_null :job_completion_summaries, :process_type, true
  end
end
