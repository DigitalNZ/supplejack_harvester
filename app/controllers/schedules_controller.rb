# frozen_string_literal: true

class SchedulesController < ApplicationController
  before_action :find_destinations, only: %i[new create show update]
  before_action :find_schedule, except: %i[index new create]
  before_action :assign_scheduleable_items, only: %i[new create show update]

  def index
    @schedules = Schedule.schedules_within_range(Time.current.to_date, 30.days.from_now.to_date)
  end

  def show; end

  def new
    @schedule = Schedule.new
  end

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
      redirect_to schedules_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      render :show
    end
  end

  def destroy
    if @schedule.destroy
      @schedule.delete_sidekiq_cron_job
      redirect_to schedules_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to schedules_path
    end
  end

  private

  def assign_scheduleable_items
    @schedulable_items = [
      ['Automations', AutomationTemplate.all.sort_by(&:name).map do |at|
        [at.name, "automation-template_#{at.id}", { data: { automation_template_id: at.id } }]
      end],
      ['Pipelines', Pipeline.all.sort_by(&:name).map do |p|
        [p.name, "pipeline_#{p.id}", { data: { pipeline_id: p.id } }]
      end]
    ]
  end

  def find_schedule
    @schedule = Schedule.find(params[:id])
  end

  def find_destinations
    @destinations = Destination.all
  end

  def schedule_params
    params[:schedule][:harvest_definitions_to_run] = [] unless params[:schedule].key?(:harvest_definitions_to_run)

    params.require(:schedule).permit(:frequency, :time, :day, :day_of_the_month, :bi_monthly_day_one,
                                     :bi_monthly_day_two, :name, :delete_previous_records, :pipeline_id,
                                     :destination_id, :automation_template_id, :job_priority, :skip_previously_enriched,
                                     harvest_definitions_to_run: [])
  end
end
