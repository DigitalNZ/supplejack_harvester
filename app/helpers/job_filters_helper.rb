# frozen_string_literal: true

# The options behind the selects above a jobs list. They carry no label beside them, so
# each option says what it filters. Choosing 'all' submits nothing rather than a sentinel
# the controller would have to know about.
module JobFiltersHelper
  # Every option says 'Run by', not just the default: a username on its own would not say
  # what it is filtering once it is the one selected.
  def user_opts
    who = User.distinct.pluck(:username).compact.sort.unshift('Schedule')

    [['Run by: anyone', '']] + who.map { |name| ["Run by: #{name}", name] }
  end

  def status_opts
    [['All statuses', '']] + %w[Queued Cancelled Completed Running Errored]
  end

  def dest_opts
    [['All destinations', '']] + Destination.distinct.pluck(:name).compact
  end
end
