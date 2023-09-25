# frozen_string_literal: true

class RemoveExtractionCopyRelationships < ActiveRecord::Migration[7.0]
  remove_reference :extraction_definitions, :original_extraction_definition
end
