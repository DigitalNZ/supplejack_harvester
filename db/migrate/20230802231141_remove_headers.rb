class RemoveHeaders < ActiveRecord::Migration[7.0]
  def change
    drop_table :headers
  end
end
