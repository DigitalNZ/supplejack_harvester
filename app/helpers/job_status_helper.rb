# frozen_string_literal: true

# A job's status as the jobs table draws it: an icon and the word, coloured rather than
# filled in. A column of them then reads as text, and only the statuses worth acting on -
# errored, and completed as its opposite - carry a colour of their own.
#
# The filled badge is still what the pages showing a single job use (JobsHelper).
module JobStatusHelper
  ICONS = {
    'queued' => 'hourglass-split',
    'running' => 'play-circle-fill',
    'completed' => 'check-circle-fill',
    'errored' => 'exclamation-triangle-fill',
    'cancelled' => 'x-circle-fill'
  }.freeze

  # Queued, running and cancelled share the grey: none of them is a result.
  TEXT_COLOURS = {
    'completed' => 'text-success',
    'errored' => 'text-danger'
  }.freeze

  def job_status_with_icon(report, job)
    status = report&.status || job.status

    tag.span(class: job_status_classes(status)) do
      safe_join([job_status_icon(status), status&.capitalize], ' ')
    end
  end

  private

  def job_status_classes(status)
    class_names('d-inline-flex', 'align-items-center', 'gap-1', 'fw-semibold',
                TEXT_COLOURS.fetch(status, 'text-secondary'))
  end

  # A status the table has never heard of still gets a mark, so that the cell is not the
  # word on its own with the others all carrying one.
  def job_status_icon(status)
    tag.i(class: "bi bi-#{ICONS.fetch(status, 'question-circle')}", aria: { hidden: true })
  end
end
