# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ErrorHandling
  include UserAuthorization
  include DeviseOverrides
  include TransformationReduxState
  include ExtractionReduxState
  include SchemaReduxState

  def paginate_and_filter_jobs(jobs)
    @status = params[:status]
    @destination = params[:destination]
    @run_by = params[:run_by]
    jobs = jobs.order(updated_at: :desc).page(params[:page])
    jobs = jobs.where(status: @status) if @status != 'All'
    jobs = jobs.where(destination: Destination.find_by(name: @destination)) if @destination != 'All'
    jobs = jobs.where(launched_by: User.find_by(username: @run_by)) if @run_by != 'All'

    jobs
  end
end
