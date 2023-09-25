# frozen_string_literal: true

class AddLastEditedBy < ActiveRecord::Migration[7.0]
  def change
    add_reference :pipelines, :last_edited_by, foreign_key: { to_table: :users }
    add_reference :transformation_definitions, :last_edited_by, foreign_key: { to_table: :users }
    add_reference :extraction_definitions, :last_edited_by, foreign_key: { to_table: :users }
  end
end
