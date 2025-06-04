# frozen_string_literal: true

class SchedulesController < ApplicationController
  # before_action :find_pipeline
  before_action :find_destinations, only: %i[new create edit update]
  # before_action :find_schedule, except: %i[index new create]

  def index
    @schedules = Schedule.all
  end

  def show; end

  def new
    @schedule = Schedule.new
    @schedulable_items = [
      ['Automations', AutomationTemplate.all.sort_by(&:name).map { |at| [at.name, at.id, { data: { automation_template_id: at.id } }] }],
      ['Pipelines', Pipeline.all.sort_by(&:name).map { |p| [p.name, p.id, { data: { pipeline_id: p.id } }] }]
    ]
  end

  def edit; end

  def create
    @schedule = Schedule.new(schedule_params)

    if @schedule.save
      @schedule.create_sidekiq_cron_job
      redirect_to schedules_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      render :new
    end
  end

  def update
    if @schedule.update(schedule_params)
      @schedule.refresh_sidekiq_cron_job
      redirect_to pipeline_schedule_path(@pipeline, @schedule), notice: t('.success')
    else
      flash.alert = t('.failure')
      render :edit
    end
  end

  def destroy
    if @schedule.destroy
      @schedule.delete_sidekiq_cron_job
      redirect_to pipeline_schedules_path(@pipeline), notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to pipeline_schedule_path(@pipeline, @schedule)
    end
  end

  private

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_schedule
    @schedule = @pipeline.schedules.find(params[:id])
  end

  def find_destinations
    @destinations = Destination.all
  end

  def schedule_params
    params[:schedule][:harvest_definitions_to_run] = [] unless params[:schedule].key?(:harvest_definitions_to_run)

    params.require(:schedule).permit(:frequency, :time, :day, :day_of_the_month, :bi_monthly_day_one,
                                     :bi_monthly_day_two, :name, :delete_previous_records,
                                     :pipeline_id, :destination_id, harvest_definitions_to_run: [])
  end
end
