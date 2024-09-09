class ChangeParameterContentColumnSize < ActiveRecord::Migration[7.1]
  def change
    change_column :parameters, :content, :text
  end
end
