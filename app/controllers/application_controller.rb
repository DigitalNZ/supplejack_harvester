# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ErrorHandling
  include UserAuthorization
  include DeviseOverrides
  include TransformationReduxState
  include ExtractionReduxState
  include SchemaReduxState

  # Who set the job going, as the jobs table labels it: a schedule or an automation
  # rather than whoever's name is on the record, and neither of those is a user, so
  # neither could be found by name. Filtering by Schedule used to find no such user and
  # silently leave the list alone, which is why it appeared to match everything.
  RUN_BY_SCHEDULE = 'Schedule'
  RUN_BY_AUTOMATION = 'Automation'

  def paginate_and_filter_jobs(jobs)
    jobs = filter_by_pipeline(jobs)
    jobs = filter_by_tags(jobs)
    jobs = filter_by_status(jobs)
    jobs = filter_by_destination(jobs)
    jobs = filter_by_run_by(jobs)

    jobs.order(created_at: :desc).page(params[:page])
  end

  private

  # Whether the jobs being listed can be filtered by a column at all. The extraction
  # jobs list comes through here too, and its route always carries a pipeline_id even
  # though extraction_jobs has no such column - asking MySQL for it would be a 500.
  def filterable?(jobs, column)
    jobs.klass.column_names.include?(column)
  end

  def filter_by_pipeline(jobs)
    pipeline_id = params[:pipeline_id]
    return jobs if pipeline_id.blank? || !filterable?(jobs, 'pipeline_id')

    jobs.where(pipeline_id:)
  end

  # A job carries no tags of its own; it inherits the ones on the pipeline that ran it,
  # so this filters on the pipeline. Several tags narrow rather than widen: the pipeline
  # behind a listed job has to carry all of them.
  def filter_by_tags(jobs)
    slugs = params[:tags]
    return jobs if slugs.blank? || !filterable?(jobs, 'pipeline_id')

    jobs.where(pipeline_id: Pipeline.tagged_with_all(slugs))
  end

  # Anything the enum does not recognise - 'All', blank, or a value typed into the URL -
  # leaves the list alone, which is how the destination and run_by filters below treat a
  # name they cannot find. Passing it through instead would match jobs with no status.
  def filter_by_status(jobs)
    status = params[:status].to_s.downcase
    return jobs unless Job::STATUSES.include?(status)

    jobs.where(status:)
  end

  def filter_by_destination(jobs)
    name = params[:destination]
    return jobs if name.blank? || name == 'All'
    return jobs unless filterable?(jobs, 'destination_id')

    destination = Destination.find_by(name:)
    return jobs if destination.blank?

    jobs.where(destination:)
  end

  def filter_by_run_by(jobs)
    run_by = params[:run_by]
    return jobs if run_by.blank? || run_by == 'All'

    case run_by
    when RUN_BY_SCHEDULE   then filter_by_launcher_column(jobs, :schedule_id)
    when RUN_BY_AUTOMATION then filter_by_launcher_column(jobs, :automation_step_id)
    else                        filter_by_launching_user(jobs, run_by)
    end
  end

  def filter_by_launcher_column(jobs, column)
    return jobs unless filterable?(jobs, column.to_s)

    jobs.where.not(column => nil)
  end

  # A job a schedule or an automation ran carries the name of whoever set that up as well,
  # and the table labels it by the schedule or the automation - so a username here means
  # the jobs that read as that person's, and leaves the other two out.
  def filter_by_launching_user(jobs, username)
    return jobs unless filterable?(jobs, 'launched_by_id')

    user = User.find_by(username:)
    return jobs if user.blank?

    jobs = jobs.where(schedule_id: nil) if filterable?(jobs, 'schedule_id')
    jobs = jobs.where(automation_step_id: nil) if filterable?(jobs, 'automation_step_id')

    jobs.where(launched_by: user)
  end
end
