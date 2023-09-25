# frozen_string_literal: true

class AddJobIdToExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    add_column :extraction_definitions, :job_id, :string
  end
end
