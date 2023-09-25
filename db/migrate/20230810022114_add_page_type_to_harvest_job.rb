# frozen_string_literal: true

class AddPageTypeToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_jobs, :page_type, :integer, default: 0
    add_column :harvest_jobs, :pages,     :integer
  end
end
