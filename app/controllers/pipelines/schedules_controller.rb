# frozen_string_literal: true

module Pipelines
  class SchedulesController < ApplicationController
    before_action :set_pipeline

    def index
      @schedules = Schedule.where(pipeline: @pipeline)
    end

    def set_pipeline
      @pipeline = Pipeline.find(params[:pipeline_id])
    end
  end
end
