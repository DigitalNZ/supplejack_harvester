# frozen_string_literal: true

module Pipelines
  # Serves the "Blocks to run" rows for the schedule form, which only knows which
  # pipeline it is scheduling once the user picks one. Rendering the same partial the
  # Run modal uses keeps the two layouts - and the two sets of input choices -
  # identical. See app/frontend/js/ScheduleSelect.js.
  class RunBlocksController < ApplicationController
    def show
      pipeline = Pipeline.find(params[:pipeline_id])
      schedule = Schedule.find_by(id: params[:schedule_id])

      render partial: 'pipelines/run_blocks',
             locals: { pipeline:, prefix: 'schedule', allow_latest: true,
                       settings: schedule&.run_settings || RunSettings.default_for(pipeline) }
    end
  end
end
