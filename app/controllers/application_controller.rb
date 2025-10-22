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
    jobs = jobs.order(updated_at: :desc).page(params[:page])
    jobs = filter_by_status(jobs)
    jobs = filter_by_destination(jobs)
    filter_by_run_by(jobs)
  end

  private

  def filter_by_pipeline(jobs)
    return jobs if params[:pipeline_id].blank?

    jobs.where(pipeline_id: params[:pipeline_id])
  end

  def filter_by_status(jobs)
    return jobs if params[:status].blank? || params[:status] == 'All'

    jobs.where(status: params[:status])
  end

  def filter_by_destination(jobs)
    return jobs if params[:destination] == 'All'

    destination = Destination.find_by(name: params[:destination])
    return jobs if destination.blank?

    jobs.where(destination: destination)
  end

  def filter_by_run_by(jobs)
    return jobs if params[:run_by] == 'All'

    user = User.find_by(username: params[:run_by])
    return jobs if user.blank?

    jobs.where(launched_by: user)
  end
end
