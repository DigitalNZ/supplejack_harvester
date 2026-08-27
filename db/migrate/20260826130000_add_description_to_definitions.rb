# frozen_string_literal: true

# The pipeline has carried a description since it was created; its extraction and
# transformation blocks are where the detail that explains one actually lives, so they
# get the same free text field. Nullable and unvalidated, like the pipeline's.
class AddDescriptionToDefinitions < ActiveRecord::Migration[8.0]
  def change
    add_column :extraction_definitions, :description, :text
    add_column :transformation_definitions, :description, :text
  end
end
