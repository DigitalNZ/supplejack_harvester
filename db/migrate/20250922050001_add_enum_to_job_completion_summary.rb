class AddEnumToJobCompletionSummary < ActiveRecord::Migration[7.2]
  def up
    # Add the enum column
    add_column :job_completion_summaries, :completion_type_enum, :integer, default: 0
    
    # Migrate existing data
    execute <<-SQL
      UPDATE job_completion_summaries 
      SET completion_type_enum = CASE 
        WHEN completion_type = 'error' THEN 0
        WHEN completion_type = 'stop_condition' THEN 1
        ELSE 0
      END
    SQL
    
    # Remove the old string column
    remove_column :job_completion_summaries, :completion_type
    
    # Rename the enum column
    rename_column :job_completion_summaries, :completion_type_enum, :completion_type
  end

  def down
    # Add back the string column
    add_column :job_completion_summaries, :completion_type_string, :string
    
    # Migrate data back
    execute <<-SQL
      UPDATE job_completion_summaries 
      SET completion_type_string = CASE 
        WHEN completion_type = 0 THEN 'error'
        WHEN completion_type = 1 THEN 'stop_condition'
        ELSE 'error'
      END
    SQL
    
    # Remove the enum column
    remove_column :job_completion_summaries, :completion_type
    
    # Rename back
    rename_column :job_completion_summaries, :completion_type_string, :completion_type
  end
end
