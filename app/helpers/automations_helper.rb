# frozen_string_literal: true

module AutomationsHelper
  def step_status_class(status)
    case status
    when 'completed'
      'completed'
    when 'running'
      'running'
    when 'errored'
      'errored'
    when 'queued'
      'queued'
    else
      'not-started'
    end
  end
end 