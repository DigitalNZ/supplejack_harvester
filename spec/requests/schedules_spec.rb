require 'rails_helper'

RSpec.describe "Schedules", type: :request do
  let(:pipeline)    { create(:pipeline) }
  let(:user)        { create(:user) }
  let(:destination) { create(:destination) }
  let(:harvest_definition)         { create(:harvest_definition, pipeline:) }
  let(:harvest_definitions_to_run) { [harvest_definition.id] }

  before do
    sign_in(user)
  end

  describe "GET /index" do
    it 'returns a successful response' do
      get schedules_path

      expect(response).to have_http_status :ok
    end
  end

  describe "GET /new" do
    it 'returns a successful response' do
      get new_schedule_path

      expect(response).to have_http_status :ok
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new schedule' do
        expect do
          post schedules_path, params: {
            schedule: attributes_for(:schedule, pipeline_id: pipeline.id, destination_id: destination.id)
          }
        end.to change(Schedule, :count).by(1)
      end

      it 'redirects to the schedules page' do
        post schedules_path, params: {
          schedule: attributes_for(:schedule, pipeline_id: pipeline.id, destination_id: destination.id)
        }

        expect(response).to redirect_to schedules_path
      end

      it 'displays an appropriate message' do
        post schedules_path, params: {
          schedule: attributes_for(:schedule, pipeline_id: pipeline.id, destination_id: destination.id)
        }

        follow_redirect!

        expect(response.body).to include 'Schedule created successfully'
      end

      it 'creates a Sidekiq::Cron::Job' do
        expect(Sidekiq::Cron::Job).to receive(:create).with(
          name: anything,
          cron: '30 12 * * * Pacific/Auckland',
          class: 'ScheduleWorker',
          args: anything
        )

        post schedules_path, params: {
          schedule: attributes_for(:schedule, harvest_definitions_to_run:, name: 'Pipeline Schedule', frequency: :daily, time: '12:30', pipeline_id: pipeline.id, destination_id: destination.id)
        }
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new schedule' do
        expect do
          post schedules_path, params: {
            schedule: {
              frequency: :daily
            }
          }
        end.to change(Schedule, :count).by(0)
      end

      it 'rerenders the :new template' do
        post schedules_path, params: {
          schedule: {
            frequency: :daily
          }
        }

        expect(response.body).to include 'New Schedule'
      end

      it 'displays an appropriate message' do
        post schedules_path, params: {
          schedule: {
            frequency: :daily
          }
        }

        expect(response.body).to include 'There was an issue creating your Schedule'
      end

      it 'does not creates a Sidekiq::Cron::Job' do
        expect(Sidekiq::Cron::Job).not_to receive(:create)

        post schedules_path, params: {
          schedule: {
            frequency: :daily
          }
        }
      end
    end
  end

  describe 'GET /edit' do
    let(:harvest_definition)         { create(:harvest_definition, pipeline:) }
    let(:harvest_definitions_to_run) { [harvest_definition.id] }
    let(:schedule)                   { create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:, name: 'Pipeline Schedule') }

    it 'returns a successful response' do
      get edit_schedule_path(schedule)

      expect(response).to have_http_status :ok
    end
  end

  describe 'PATCH /update' do
    let(:harvest_definition)         { create(:harvest_definition, pipeline:) }
    let(:harvest_definitions_to_run) { [harvest_definition.id] }
    let(:schedule)                   { create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:, name: 'Pipeline Schedule') }

    context 'with valid parameters' do
      it 'updates the schedule' do
        patch schedule_path(schedule), params: {
          schedule: {
            name: 'Changed Name',
            harvest_definitions_to_run:
          }
        }

        schedule.reload

        expect(schedule.name).to eq 'Changed Name'
      end

      it 'redirects to the schedules page' do
        patch schedule_path(schedule), params: {
          schedule: {
            name: 'Changed Name',
            harvest_definitions_to_run:
          }
        }

        expect(response).to redirect_to schedules_path
      end

      it 'displays an appropriate message' do
        patch schedule_path(schedule), params: {
          schedule: {
            name: 'Changed Name',
            harvest_definitions_to_run:
          }
        }

        follow_redirect!

        expect(response.body).to include 'Schedule updated successfully'
      end

      it 'updates the Sidekiq::Cron::Job with the new details' do
        Sidekiq::Cron::Job.destroy_all!

        post schedules_path, params: {
          schedule: attributes_for(:schedule, harvest_definitions_to_run:, name: 'Schedule', frequency: :daily, time: '12:30', pipeline_id: pipeline.id, destination_id: destination.id)
        }

        sidekiq_cron  = Sidekiq::Cron::Job.all.first

        expect(Sidekiq::Cron::Job.all.count).to eq 1
        expect(sidekiq_cron.cron).to eq '30 12 * * * Pacific/Auckland'

        patch schedule_path(Schedule.last), params: {
          schedule: {
            harvest_definitions_to_run:,
            time: '11:45'
          }
        }

        sidekiq_cron  = Sidekiq::Cron::Job.all.first

        expect(Sidekiq::Cron::Job.all.count).to eq 1
        expect(sidekiq_cron.cron).to eq '45 11 * * * Pacific/Auckland'
      end
    end

    context 'with invalid parameters' do
      it 'does not update the schedule' do
        patch schedule_path(schedule), params: {
          schedule: {
            name: ''
          }
        }

        schedule.reload

        expect(schedule.name).not_to eq ''
      end

      it 're-renders the edit form' do
        patch schedule_path(schedule), params: {
          schedule: {
            name: ''
          }
        }

        expect(response.body).to include 'Edit Schedule'
      end

      it 'displays an appropriate message' do
        patch schedule_path(schedule), params: {
          schedule: {
            name: ''
          }
        }

        expect(response.body).to include 'There was an issue updating your Schedule'
      end
    end
  end

  describe 'DELETE /destroy' do
    let(:harvest_definition)         { create(:harvest_definition, pipeline:) }
    let(:harvest_definitions_to_run) { [harvest_definition.id] }
    let!(:schedule)                   { create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:, name: 'Pipeline Schedule') }

    context 'when the destroy is successful' do
      it 'deletes the schedule' do
        expect do
          delete schedule_path(schedule)
        end.to change(Schedule, :count).by(-1)
      end

      it 'redirects to the pipeline schedules page' do
        delete schedule_path(schedule)

        expect(response).to redirect_to schedules_path
      end

      it 'displays an appropriate message' do
        delete schedule_path(schedule)

        follow_redirect!

        expect(response.body).to include 'Schedule deleted successfully'
      end
    end

    context 'when the destroy is not successful' do
      before do
        allow_any_instance_of(Schedule).to receive(:destroy).and_return(false)
      end

      it 'does not delete the schedule' do
        expect do
          delete schedule_path(schedule)
        end.to change(Schedule, :count).by(0)
      end

      it 'redirects to the pipeline schedule page' do
        delete schedule_path(schedule)

        expect(response).to redirect_to schedules_path
      end

      it 'displays an appropriate message' do
        delete schedule_path(schedule)

        follow_redirect!

        expect(response.body).to include 'There was an issue deleting your Schedule'
      end
    end
  end
end
