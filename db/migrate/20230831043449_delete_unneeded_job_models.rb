# frozen_string_literal: true

class DeleteUnneededJobModels < ActiveRecord::Migration[7.0]
  def change
    drop_table :delete_jobs
    drop_table :transformation_jobs
    drop_table :load_jobs
  end
end
