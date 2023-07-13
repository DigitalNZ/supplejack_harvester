# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include UserAuthorization
  include DeviseOverrides
  include ReduxState

  def paginate_and_filter_jobs(jobs)
    @status = params[:status]
    jobs = jobs.order(updated_at: :desc).page(params[:page])
    jobs = jobs.where(status: @status) if @status

    jobs
  end
end
