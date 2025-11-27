class RemoveNameFromSchedules < ActiveRecord::Migration[7.2]
  def up
    # Drop the unique index on name first (as defined in schema.rb)
    if index_exists?(:schedules, :name, name: "index_schedules_on_name")
      remove_index :schedules, name: "index_schedules_on_name"
    end

    remove_column :schedules, :name
  end

  def down
    add_column :schedules, :name, :string

    # Restore the unique index
    add_index :schedules, :name, unique: true, name: "index_schedules_on_name"
  end
end
