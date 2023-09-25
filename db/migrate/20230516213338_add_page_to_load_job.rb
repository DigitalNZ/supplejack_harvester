# frozen_string_literal: true

class AddPageToLoadJob < ActiveRecord::Migration[7.0]
  def change
    add_column :load_jobs, :page, :integer, null: false, default: 1
  end
end
