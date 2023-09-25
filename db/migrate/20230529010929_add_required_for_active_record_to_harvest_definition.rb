# frozen_string_literal: true

class AddRequiredForActiveRecordToHarvestDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :harvest_definitions, :required_for_active_record, :boolean, default: false
  end
end
