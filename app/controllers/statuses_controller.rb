# frozen_string_literal: true

# Every status the app can draw, on one page, so that the vocabulary can be read in one
# place rather than gathered off the pages that happen to be showing one.
#
# The list comes from the models that declare them rather than from a list of its own: a job
# and its report stages carry Job::STATUSES, an automation and its steps carry whatever
# StatusManagement can work out. A status added to either appears here without this being
# touched.
class StatusesController < ApplicationController
  # What has not run, then what is under way, then how it turned out. A status a model
  # declares and this does not name is shown after these rather than left out.
  DISPLAY_ORDER = %w[not_started queued running completed cancelled errored failed].freeze

  def index
    @statuses = declared_statuses.sort_by { |status| DISPLAY_ORDER.index(status) || DISPLAY_ORDER.length }
  end

  private

  def declared_statuses
    (Job::STATUSES + ['napping']) | StatusManagement::STATUS_PRIORITY.keys
  end
end
