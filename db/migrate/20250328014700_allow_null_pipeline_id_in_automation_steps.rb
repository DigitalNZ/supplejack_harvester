# frozen_string_literal: true

class AllowNullPipelineIdInAutomationSteps < ActiveRecord::Migration[7.1]
  def up
    change_column_null :automation_steps, :pipeline_id, true
    change_column_null :automation_step_templates, :pipeline_id, true
  end

  def down
    change_column_null :automation_steps, :pipeline_id, false
    change_column_null :automation_step_templates, :pipeline_id, false
  end
end 