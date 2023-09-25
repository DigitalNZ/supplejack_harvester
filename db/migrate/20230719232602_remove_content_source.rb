# frozen_string_literal: true

class RemoveContentSource < ActiveRecord::Migration[7.0]
  def change
    remove_reference :extraction_definitions, :content_source
    remove_reference :harvest_definitions, :content_source
    remove_reference :transformation_definitions, :content_source
    drop_table :content_sources
  end
end
