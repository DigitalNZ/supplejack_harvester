# frozen_string_literal: true

module AutomationsHelper
  # Map of status to CSS class names for automation steps
  STEP_STATUS_MAPPING = {
    'completed' => 'completed',
    'running' => 'running',
    'errored' => 'errored',
    'queued' => 'queued'
  }.freeze

  def step_status_class(status)
    STEP_STATUS_MAPPING[status] || 'not-started'
  end
end
