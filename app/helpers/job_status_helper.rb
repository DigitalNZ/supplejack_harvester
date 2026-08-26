# frozen_string_literal: true

# A status as the jobs table draws it: an icon and the word, coloured rather than filled
# in. A column of them then reads as text, and only the statuses worth acting on -
# errored and failed, and completed as their opposite - carry a colour of their own.
#
# Every page that shows the status of a job, of one of its report's stages, of an
# automation or of one of its steps draws it this way, so that the same word looks the
# same wherever it is read.
module JobStatusHelper
  ICONS = {
    'not_started' => 'dash-circle',
    'queued' => 'hourglass-split',
    'running' => 'play-circle-fill',
    'completed' => 'check-circle-fill',
    'errored' => 'exclamation-triangle-fill',
    'failed' => 'exclamation-octagon-fill',
    'cancelled' => 'x-circle-fill'
  }.freeze

  # Queued, running, cancelled and not started share the grey: none of them is a result.
  TEXT_COLOURS = {
    'completed' => 'text-success',
    'errored' => 'text-danger',
    'failed' => 'text-danger'
  }.freeze

  # A block's status is the status of its harvest report, and the job's own until the
  # report exists.
  def job_status_with_icon(report, job)
    status_with_icon(report&.status || job&.status)
  end

  # Nothing to read a status from is a status of its own: an automation nobody has run
  # yet, or a harvest definition the last run never reached, has not started rather than
  # having an unknown status.
  def status_with_icon(status)
    status = status.presence || 'not_started'

    tag.span(class: job_status_classes(status)) do
      safe_join([job_status_icon(status), status.humanize], ' ')
    end
  end

  private

  def job_status_classes(status)
    class_names('d-inline-flex', 'align-items-center', 'gap-1', 'fw-semibold', 'text-nowrap',
                TEXT_COLOURS.fetch(status, 'text-secondary'))
  end

  # A status the app has never heard of still gets a mark, so that it is not the word on
  # its own with the others around it all carrying one.
  def job_status_icon(status)
    tag.i(class: "bi bi-#{ICONS.fetch(status, 'question-circle')}", aria: { hidden: true })
  end
end
