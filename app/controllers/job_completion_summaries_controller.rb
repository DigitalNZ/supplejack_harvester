# frozen_string_literal: true

class JobCompletionSummariesController < ApplicationController
  before_action :set_job_completion_summary, only: [:show]

  def index
    @job_completion_summaries = JobCompletionSummary.recent_completions.page(params[:page])

    if params[:completion_type].present?
      @job_completion_summaries = @job_completion_summaries.by_completion_type(params[:completion_type])
    end

    return if params[:extraction_id].blank?

    @job_completion_summaries = @job_completion_summaries.where(extraction_id: params[:extraction_id])
  end

  def show; end

  private

  def set_job_completion_summary
    @job_completion_summary = JobCompletionSummary.find(params[:id])
  end
end
