class AddJobTypeToJobErrors < ActiveRecord::Migration[7.2]
  def change
    add_column :job_errors, :job_type, :string, null: false
    add_index :job_errors, :job_type
  end
end