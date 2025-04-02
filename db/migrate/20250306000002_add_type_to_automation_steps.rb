# frozen_string_literal: true

class AddTypeToAutomationSteps < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_steps, :step_type, :string, default: 'pipeline', null: false
  end
end 