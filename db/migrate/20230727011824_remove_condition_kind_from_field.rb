# frozen_string_literal: true

class RemoveConditionKindFromField < ActiveRecord::Migration[7.0]
  def change
    remove_column :fields, :condition
  end
end
