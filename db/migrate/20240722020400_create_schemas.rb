class CreateSchemas < ActiveRecord::Migration[7.1]
  def change
    create_table :schemas do |t|
      t.text 'name'
      t.timestamps
    end
  end
end
