# frozen_string_literal: true

class AddNameToExtractionJob < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_jobs, :name, :text
  end
end
