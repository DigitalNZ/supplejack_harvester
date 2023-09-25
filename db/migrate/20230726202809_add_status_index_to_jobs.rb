# frozen_string_literal: true

class AddStatusIndexToJobs < ActiveRecord::Migration[7.0]
  def change
    add_index :harvest_jobs,        :status
    add_index :extraction_jobs,     :status
    add_index :transformation_jobs, :status
    add_index :load_jobs,           :status
  end
end
