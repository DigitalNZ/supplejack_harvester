# frozen_string_literal: true

class RemoveContentSourceRequirementFromExtractionDefinition < ActiveRecord::Migration[7.0]
  def change
    change_column_null :extraction_definitions, :content_source_id, true
    # change_column_null :transformation_definitions, :content_source_id, true
  end
end
