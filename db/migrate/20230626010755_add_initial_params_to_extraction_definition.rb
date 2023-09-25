# frozen_string_literal: true

class AddInitialParamsToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :initial_params, :string
  end
end
