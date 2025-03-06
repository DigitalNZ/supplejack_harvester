# frozen_string_literal: true

module ApplicationHelper
  def current_page(controller, actions)
    controller_name == controller.to_s && action_name.in?(actions)
  end

  def breadcrumb_item(text:, path: nil, display: true, active: false)
    return unless display

    tag.li(class: { 'breadcrumb-item': true, active: }) do
      path && !active ? link_to(text, path) : text&.to_s
    end
  end

  def last_edited_by(resource)
    return if resource&.last_edited_by.nil?

    "Last edited by #{resource.last_edited_by.username}"
  end

  def step_status_class(status)
    case status
    when 'completed'
      'status-completed'
    when 'running'
      'status-running'
    when 'errored'
      'status-errored'
    when 'queued'
      'status-queued'
    else
      'status-not_started'
    end
  end

  # Returns the appropriate Bootstrap badge class based on automation status
  def status_badge_class(status)
    case status
    when 'completed'
      'bg-success'
    when 'failed'
      'bg-danger'
    when 'running'
      'bg-primary'
    when 'queued'
      'bg-info'
    when 'not_started'
      'bg-secondary'
    else
      'bg-secondary'
    end
  end
end
