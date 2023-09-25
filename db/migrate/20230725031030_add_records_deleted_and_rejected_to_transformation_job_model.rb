# frozen_string_literal: true

class AddRecordsDeletedAndRejectedToTransformationJobModel < ActiveRecord::Migration[7.0]
  def change
    add_column :transformation_jobs, :records_rejected, :integer, default: 0
    add_column :transformation_jobs, :records_deleted, :integer, default: 0
  end
end
