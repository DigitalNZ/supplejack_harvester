# frozen_string_literal: true

# How the request to the destination is made, rather than what it carries. The destination's
# create_batch updates one record per request, serially, so its working time tracks the size of
# the batch - a 550KB page of NLNZcat took 73 seconds against a 60 second timeout while a 143KB
# page took 24. Either column answers that: wait longer, or send less at once.
#
# read_timeout is nullable, and nil means the app-wide default in config/initializers/faraday.rb
# still stands. batch_size is not, because LoadWorker has always sliced at 100.
class AddRequestSettingsToLoadDefinitions < ActiveRecord::Migration[8.0]
  def change
    add_column :load_definitions, :read_timeout, :integer, null: true
    add_column :load_definitions, :batch_size, :integer, null: false, default: 100
  end
end
