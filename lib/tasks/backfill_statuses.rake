# frozen_string_literal: true

# ------------------------------------------------------------
# Repairs the run and block statuses left behind by the status defects. See
# lib/backfill_statuses.rb for what each pass repairs and why it writes the way it does.
#
# Dry run unless APPLY=true, so the counts can be read before anything is written.
#
#   bundle exec rake backfill_statuses:execute
#   bundle exec rake backfill_statuses:execute LIMIT=20 APPLY=true
#   bundle exec rake backfill_statuses:execute APPLY=true
#
# Env:
#   APPLY             false      write the repairs; otherwise only report them
#   MIN_AGE_HOURS     24         leave anything touched more recently alone, so a run in
#                                flight is never mistaken for an abandoned one
#   ABANDONED_STATUS  cancelled  what a run that never started becomes. Terminal, so it does
#                                not sit under the jobs page's Queued filter as if it were due
#   ONLY              ''         'reports' or 'runs' to do just one of the passes
#   LIMIT             ''         stop after this many repairs in each pass, for a smaller
#                                first bite
#
# Reports are repaired before runs, because a block finishing is what decides whether its run
# has: expect a second run of this to end more runs than the first dry run predicted.
# ------------------------------------------------------------
namespace :backfill_statuses do
  desc 'Repair run and block statuses left behind by the status defects. Dry run unless APPLY=true.'
  task execute: :environment do
    config = BackfillStatuses::Config.new

    puts config.apply? ? 'Applying repairs.' : 'Dry run - nothing will be written. Set APPLY=true to write.'
    puts "Leaving anything touched since #{config.cutoff.iso8601} alone."
    puts

    if config.reports?
      puts 'Blocks left running with every worker accounted for:'
      puts BackfillStatuses::Reports.new(config).call
      puts
    end

    if config.runs?
      puts 'Runs left running though they finished, and runs with no status:'
      puts BackfillStatuses::Runs.new(config).call
      puts
    end

    puts 'Done.'
  end
end
