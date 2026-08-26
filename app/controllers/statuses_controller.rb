# frozen_string_literal: true

# Every status the app can draw, on one page, so that the vocabulary can be read in one
# place rather than gathered off the pages that happen to be showing one.
#
# The list comes from the models that declare them rather than from a list of its own: a job
# and its report stages carry Job::STATUSES, an automation and its steps carry whatever
# StatusManagement can work out. A status added to either appears here without this being
# touched.
class StatusesController < ApplicationController
  # What each status says, in the order the page reads best in: what has not run, then what
  # is under way, then how it turned out. A status a model declares and this does not
  # describe is still shown, after these and without a sentence, rather than left out.
  DESCRIPTIONS = {
    'napping' => 'A status the app does not know about, but which a model has declared.',
    'not_started' => 'Nothing has run yet.',
    'queued' => 'Waiting for a worker to pick it up.',
    'running' => 'Under way now.',
    'completed' => 'Finished, and did what it was asked to.',
    'cancelled' => 'Stopped by someone before it finished.',
    'errored' => 'Stopped on an error.',
    'failed' => 'An automation with an errored step in it.'
  }.freeze

  def index
    @statuses = declared_statuses.sort_by { |status| position(status) }
                                 .map { |status| [status, DESCRIPTIONS[status]] }
  end

  private

  def declared_statuses
    (Job::STATUSES + ['napping']) | StatusManagement::STATUS_PRIORITY.keys
  end

  def position(status)
    DESCRIPTIONS.keys.index(status) || DESCRIPTIONS.length
  end
end
