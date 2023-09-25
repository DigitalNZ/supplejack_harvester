# frozen_string_literal: true

class AddNameToTransformationJob < ActiveRecord::Migration[7.0]
  def change
    add_column :transformation_jobs, :name, :text
  end
end
