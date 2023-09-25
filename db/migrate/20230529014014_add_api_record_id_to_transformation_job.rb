# frozen_string_literal: true

class AddApiRecordIdToTransformationJob < ActiveRecord::Migration[7.0]
  def change
    add_column :transformation_jobs, :api_record_id, :string
  end
end
