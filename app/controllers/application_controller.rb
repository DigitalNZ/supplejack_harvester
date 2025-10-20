# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ErrorHandling
  include UserAuthorization
  include DeviseOverrides
  include TransformationReduxState
  include ExtractionReduxState
  include SchemaReduxState

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def paginate_and_filter_jobs(jobs)
    status      = params[:status]
    destination = params[:destination]
    run_by      = params[:run_by]
    pipeline_id = params[:pipeline_id]

    jobs = jobs.where(pipeline_id: pipeline_id) if pipeline_id.present?
    jobs = jobs.order(updated_at: :desc).page(params[:page])
    jobs = jobs.where(status: status) if status != 'All'

    if destination != 'All'
      dest = Destination.find_by(name: destination)
      jobs = jobs.where(destination: dest) if dest
    end

    if run_by != 'All'
      user = User.find_by(username: run_by)
      jobs = jobs.where(launched_by: user) if user
    end

    jobs
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
