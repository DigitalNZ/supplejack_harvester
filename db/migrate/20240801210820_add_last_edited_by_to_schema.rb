class AddLastEditedByToSchema < ActiveRecord::Migration[7.1]
  def change
    add_reference :schemas, :last_edited_by, foreign_key: { to_table: :users }
  end
end
