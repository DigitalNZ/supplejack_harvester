# frozen_string_literal: true

class AddFieldsAndSubDocumentsToExtractionDefinition < ActiveRecord::Migration[7.1]
  def change
    add_column :extraction_definitions, :fields, :text
    add_column :extraction_definitions, :include_sub_documents, :boolean, default: true, null: false
  end
end
