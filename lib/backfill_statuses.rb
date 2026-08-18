# frozen_string_literal: true

# Repairs the statuses left behind by defects that are now fixed. Nothing here changes what a
# run did - only what it says about itself. Driven by lib/tasks/backfill_statuses.rake.
#
# Two things to repair, in this order, because the first decides the second:
#
#   Reports  A block left showing running with every one of its workers accounted for. The
#            transformation/load/delete hand-off between workers could lose the last one
#            (fixed by the reload in ExtractionWorker#update_harvest_report!), and
#            Pipeline#complete_finished_jobs! only ever reached the reports of a pipeline an
#            automation happened to be waiting on.
#
#   Runs     A run left showing running though every block of it had finished, and a run left
#            with no status at all. The first was RunCompletion reading a stale copy of the
#            report whose status had just changed; the second was pipeline_jobs.status having
#            no default, so a run whose worker never arrived never got one.
#
# Written with update_columns, deliberately: PipelineJob's before_validation
# (RunConfiguration#derive_harvest_definitions_to_run) rewrites harvest_definitions_to_run,
# and this must not edit what a historical run was configured to do on its way past. It also
# keeps a legacy row that would fail today's validations from blocking its own repair.
# Neither model has an after_update hook this needs.
#
# Reports first also means their end times come from the report's own last activity rather
# than from now - a run repaired through the callbacks would stamp today onto a harvest that
# finished in June.
module BackfillStatuses
  COMPLETED = 'completed'
  STEPS = %w[transformation load delete].freeze

  class Config
    DEFAULTS = {
      'APPLY' => 'false',
      'MIN_AGE_HOURS' => '24',
      'ABANDONED_STATUS' => 'cancelled',
      'ONLY' => '',
      'LIMIT' => ''
    }.freeze

    attr_reader :abandoned_status, :only

    def apply? = @apply

    def initialize(env = ENV)
      @apply            = truthy?(fetch(env, 'APPLY'))
      @min_age_hours    = fetch(env, 'MIN_AGE_HOURS').to_i
      @abandoned_status = fetch(env, 'ABANDONED_STATUS')
      @only             = fetch(env, 'ONLY')
      @limit            = fetch(env, 'LIMIT')
    end

    def cutoff = @min_age_hours.hours.ago

    def limit = @limit.presence&.to_i

    def reports? = @only.blank? || @only == 'reports'

    def runs? = @only.blank? || @only == 'runs'

    def validate!
      return if PipelineJob.statuses.key?(@abandoned_status)

      raise ArgumentError, "ABANDONED_STATUS must be one of #{PipelineJob.statuses.keys.join(', ')}"
    end

    private

    def fetch(env, key) = env.fetch(key, DEFAULTS.fetch(key))

    def truthy?(value) = %w[1 true TRUE yes YES on ON].include?(value)
  end

  # Tallies what was seen, so a dry run and a real run report the same way.
  class Tally
    def initialize = @counts = Hash.new(0)

    def record(outcome)
      @counts[outcome] += 1
      outcome
    end

    def count(outcome) = @counts[outcome]

    def to_s
      return '  nothing to do' if @counts.empty?

      @counts.sort_by { |_, count| -count }
             .map { |outcome, count| "  #{outcome}: #{count}" }
             .join("\n")
    end
  end

  # Walks a set of candidates, asking each subclass what to make of one and what to do about
  # it. #examine returns nil for a record there is nothing to do about, having recorded why.
  class Sweep
    def initialize(config) = @config = config

    def call
      tally = Tally.new
      applied = 0

      candidates.find_each do |record|
        outcome = examine(record, tally)
        next if outcome.nil?
        break if over_limit?(applied += 1)

        tally.record(commit(record, outcome))
      end

      tally
    end

    private

    def over_limit?(count)
      limit = @config.limit
      limit.present? && count > limit
    end
  end

  # A block left showing running with every one of its workers accounted for.
  class Reports < Sweep
    private

    def examine(report, tally)
      return unless report.status == 'running'

      repairs = repairs_for(report)
      return repairs if repairs.present?

      tally.record(:cannot_repair)
      nil
    end

    # Reports whose four statuses are not all completed, on a run old enough to be certainly
    # not in flight. A report with no run cannot have one repaired, so the join drops it.
    #
    # Bound as the enum's integer, not as 'completed': these are integer columns, and MySQL
    # reads a non-numeric string in a numeric comparison as 0 - which would quietly have asked
    # for the reports that are not all *queued*.
    def candidates
      HarvestReport.joins(:pipeline_job)
                   .where(pipeline_jobs: { updated_at: ...@config.cutoff })
                   .where.not(all_statuses_completed, completed: completed_value)
    end

    def all_statuses_completed
      (['extraction'] + STEPS).map { |step| "#{step}_status = :completed" }.join(' AND ')
    end

    def completed_value = HarvestReport.extraction_statuses.fetch(COMPLETED)

    # Each step is asked in order, because load_workers_completed? and
    # delete_workers_completed? both want the transformation completed - so the answer for one
    # depends on the step before it having been taken. Assigned in memory to get that,
    # written once.
    def repairs_for(report)
      (STEPS - unreachable_steps(report)).each_with_object({}) do |step, repairs|
        next unless report.public_send(:"#{step}_workers_completed?")

        report.public_send(:"#{step}_status=", COMPLETED)
        repairs[:"#{step}_status"] = COMPLETED
        repairs[:"#{step}_end_time"] = finished_at(report) if report.public_send(:"#{step}_end_time").blank?
      end
    end

    # A step already completed has nothing to repair. Nothing at all can be decided from the
    # worker counts while the extraction itself is unfinished, because every one of those
    # checks asks whether it completed first.
    def unreachable_steps(report)
      return STEPS unless report.extraction_completed?

      STEPS.select { |step| report.public_send(:"#{step}_completed?") }
    end

    # When the block actually stopped working, as far as anything recorded it.
    def finished_at(report) = report.last_updated || report.updated_at

    def commit(report, repairs)
      return :would_repair unless @config.apply?

      report.update_columns(repairs) # rubocop:disable Rails/SkipsModelValidations
      :repaired
    end
  end

  # A run left showing running though its blocks finished, or left with no status at all.
  class Runs < Sweep
    private

    def examine(job, tally)
      outcome = classify(job)
      return outcome unless outcome == :unfinished

      tally.record(:still_working)
      nil
    end

    # Runs with no status and runs still showing running, old enough that none of them can be
    # one that is genuinely under way.
    def candidates
      PipelineJob.where(status: [nil, PipelineJob.statuses['running']])
                 .where(updated_at: ...@config.cutoff)
    end

    # RunCompletion is asked rather than reimplemented, so a run is only ended here on the same
    # terms the app would end it on now.
    def classify(job)
      return :abandoned if never_started?(job)

      completion = RunCompletion.new(job)
      return :unfinished unless completion.finished?

      completion.errored? ? :errored : :completed
    end

    # Nothing of it ever ran: no start time, and not one block. Its worker never arrived.
    def never_started?(job)
      job.start_time.blank? && job.harvest_jobs.none? && job.harvest_reports.none?
    end

    def commit(job, outcome)
      return :"would_#{outcome}" unless @config.apply?

      job.update_columns(attributes_for(job, outcome)) # rubocop:disable Rails/SkipsModelValidations
      outcome
    end

    def attributes_for(job, outcome)
      attributes = { status: status_for(outcome) }
      finished_at = finished_at(job)
      attributes[:end_time] = finished_at if job.end_time.blank? && finished_at.present?
      attributes
    end

    def status_for(outcome)
      outcome == :abandoned ? @config.abandoned_status : outcome.to_s
    end

    # The last thing any of its blocks recorded, never earlier than the run started. An
    # abandoned run has no blocks and so keeps its empty times.
    def finished_at(job)
      times = job.harvest_reports.filter_map { |report| report.last_updated || report.updated_at }
      return nil if times.empty?

      [times.max, job.start_time].compact.max
    end
  end
end
