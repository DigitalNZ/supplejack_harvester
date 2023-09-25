# frozen_string_literal: true

class RemoveTransformationCopyReference < ActiveRecord::Migration[7.0]
  def change
    remove_reference :transformation_definitions, :original_transformation_definition
  end
end
