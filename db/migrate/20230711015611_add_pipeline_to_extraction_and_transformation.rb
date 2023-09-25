# frozen_string_literal: true

class AddPipelineToExtractionAndTransformation < ActiveRecord::Migration[7.0]
  def change
    add_reference :extraction_definitions, :pipeline
    add_reference :transformation_definitions, :pipeline

    change_column_null :transformation_definitions, :content_source_id, true
  end
end
