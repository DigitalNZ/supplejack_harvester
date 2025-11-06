class CreateJobCompletions < ActiveRecord::Migration[7.2]
  def change
    create_table :job_completions do |t|
      t.timestamps
    end
  end
end
