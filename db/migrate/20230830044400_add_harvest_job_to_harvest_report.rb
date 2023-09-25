# frozen_string_literal: true

class AddHarvestJobToHarvestReport < ActiveRecord::Migration[7.0]
  def change
    remove_reference :harvest_reports, :harvest_definition
    add_reference    :harvest_reports, :harvest_job
  end
end
