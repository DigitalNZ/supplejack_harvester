# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ErrorHandling
  include UserAuthorization
  include DeviseOverrides
  include TransformationReduxState
  include ExtractionReduxState
  include SchemaReduxState

  def paginate_and_filter_jobs(jobs)
    jobs = filter_by_pipeline(jobs)
    jobs = filter_by_tags(jobs)
    jobs = filter_by_status(jobs)
    jobs = filter_by_destination(jobs)
    jobs = filter_by_run_by(jobs)

    jobs.order(updated_at: :desc).page(params[:page])
  end

  private

  # Whether the jobs being listed can be filtered by a column at all. The extraction
  # jobs list comes through here too, and its route always carries a pipeline_id even
  # though extraction_jobs has no such column - asking MySQL for it would be a 500.
  def filterable?(jobs, column)
    jobs.klass.column_names.include?(column)
  end

  def filter_by_pipeline(jobs)
    return jobs if params[:pipeline_id].blank? || !filterable?(jobs, 'pipeline_id')

    jobs.where(pipeline_id: params[:pipeline_id])
  end

  # A job carries no tags of its own; it inherits the ones on the pipeline that ran it,
  # so this filters on the pipeline. Several tags narrow rather than widen: the pipeline
  # behind a listed job has to carry all of them.
  def filter_by_tags(jobs)
    return jobs if params[:tags].blank? || !filterable?(jobs, 'pipeline_id')

    jobs.where(pipeline_id: Pipeline.tagged_with_all(params[:tags]))
  end

  # Anything the enum does not recognise - 'All', blank, or a value typed into the URL -
  # leaves the list alone, which is how the destination and run_by filters below treat a
  # name they cannot find. Passing it through instead would match jobs with no status.
  def filter_by_status(jobs)
    status = params[:status].to_s.downcase
    return jobs unless jobs.klass.statuses.key?(status)

    jobs.where(status:)
  end

  def filter_by_destination(jobs)
    return jobs if params[:destination].blank? || params[:destination] == 'All'
    return jobs unless filterable?(jobs, 'destination_id')

    destination = Destination.find_by(name: params[:destination])
    return jobs if destination.blank?

    jobs.where(destination:)
  end

  def filter_by_run_by(jobs)
    return jobs if params[:run_by].blank? || params[:run_by] == 'All'
    return jobs unless filterable?(jobs, 'launched_by_id')

    user = User.find_by(username: params[:run_by])
    return jobs if user.blank?

    jobs.where(launched_by: user)
  end
end
