# frozen_string_literal: true

# The options behind the selects above a jobs list. They carry no label beside them, so
# each option says what it filters. Choosing 'all' submits nothing rather than a sentinel
# the controller would have to know about.
module JobFiltersHelper
  # Every option says 'Run by', not just the default: a username on its own would not say
  # what it is filtering once it is the one selected. Schedule and Automation lead the
  # list because they are how most jobs are labelled, and they are not users - a person
  # named either of those would be indistinguishable here, which no one is.
  def user_opts
    who = User.distinct.pluck(:username).compact.sort
    who.unshift(ApplicationController::RUN_BY_SCHEDULE, ApplicationController::RUN_BY_AUTOMATION)

    [['Run by: anyone', '']] + who.map { |name| ["Run by: #{name}", name] }
  end

  def status_opts
    [['All statuses', '']] + %w[Queued Cancelled Completed Running Errored]
  end

  def dest_opts
    [['All destinations', '']] + Destination.distinct.order(:name).pluck(:name).compact
  end
end
