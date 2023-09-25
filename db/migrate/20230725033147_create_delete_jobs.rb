# frozen_string_literal: true

class CreateDeleteJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :delete_jobs do |t|
      t.integer 'status'
      t.integer 'kind', default: 0, null: false
      t.timestamp 'start_time'
      t.timestamp 'end_time'
      t.integer 'records_deleted', default: 0
      t.text 'name'
      t.integer 'page', default: 1, null: false

      t.timestamps
    end

    add_reference :delete_jobs, :harvest_job
  end
end
