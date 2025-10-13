# frozen_string_literal: true

class JobCompletionSummariesController < ApplicationController
  def index
    @job_completion_summaries = JobCompletionSummary.recent_completions.page(params[:page])

    completion_type = params[:completion_type]
    extraction_id = params[:extraction_id]

    if completion_type.present?
      @job_completion_summaries = @job_completion_summaries.by_completion_type(completion_type)
    end

    return if extraction_id.blank?

    @job_completion_summaries = @job_completion_summaries.where(extraction_id: extraction_id)
  end

  def show
    @job_completion_summary = JobCompletionSummary.find(params[:id])
  end
end
