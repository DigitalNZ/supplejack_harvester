# frozen_string_literal: true

class AddColorToTags < ActiveRecord::Migration[8.0]
  def change
    # 0 is the first colour the enum on Tag declares, the grey every tag starts as.
    add_column :tags, :color, :integer, default: 0, null: false
  end
end
