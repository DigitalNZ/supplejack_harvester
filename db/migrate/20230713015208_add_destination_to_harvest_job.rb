# frozen_string_literal: true

class AddDestinationToHarvestJob < ActiveRecord::Migration[7.0]
  def change
    add_reference :harvest_jobs, :destination
    remove_reference :harvest_definitions, :destination
  end
end
