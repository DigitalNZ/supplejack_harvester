class CreatePipelineJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :pipeline_jobs do |t|
      t.timestamp 'start_time'
      t.timestamp 'end_time'
      t.text      'name'
      t.integer   'status'
      t.timestamps
    end

    add_reference :pipeline_block_reports, :pipeline_job
  end
end
