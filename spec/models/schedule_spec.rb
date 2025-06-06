require 'rails_helper'

RSpec.describe Schedule, type: :model do
  let(:pipeline)                   { create(:pipeline) }
  let(:destination)                { create(:destination) }
  let(:harvest_definition)         { create(:harvest_definition, pipeline:) }
  let(:harvest_definitions_to_run) { [harvest_definition.id] }

  describe 'associations' do
    it { is_expected.to belong_to(:pipeline).optional }
    it { is_expected.to belong_to(:automation_template).optional }
    it { is_expected.to belong_to(:destination) }
    it { is_expected.to have_many(:pipeline_jobs) }
  end

  describe '#name' do
    it 'assigns a name based on the pipeline and destination' do
      schedule = create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:)
      expect(schedule.name).to eq "#{pipeline.name.parameterize(separator: '_')}__#{destination.name.parameterize(separator: '_')}__#{schedule.time.parameterize(separator: '_')}"
    end
  end

  describe 'frequency' do
    it 'can be daily' do
      daily = build(:schedule, frequency: 0, pipeline:, destination:, harvest_definitions_to_run:)

      expect(daily.daily?).to be true
    end

    it 'can be weekly' do
      weekly = build(:schedule, frequency: 1, pipeline:, destination:, harvest_definitions_to_run:)
      expect(weekly.weekly?).to be true
    end

    it 'can be bi_monthly' do
      fortnightly = build(:schedule, frequency: 2, pipeline:, destination:, harvest_definitions_to_run:)
      expect(fortnightly.bi_monthly?).to be true
    end

    it 'can be monthly' do
      monthly = build(:schedule, frequency: 3, pipeline:, destination:, harvest_definitions_to_run:)
      expect(monthly.monthly?).to be true
    end
  end

  describe 'day' do
    it 'can be on Monday' do
      schedule = create(:schedule, frequency: 0, day: 1, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_monday?).to be true
    end

    it 'can be on Tuesday' do
      schedule = create(:schedule, frequency: 0, day: 2, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_tuesday?).to be true
    end

    it 'can be on Wednesday' do
      schedule = create(:schedule, frequency: 0, day: 3, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_wednesday?).to be true
    end

    it 'can be on Thursday' do
      schedule = create(:schedule, frequency: 0, day: 4, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_thursday?).to be true
    end

    it 'can be on Friday' do
      schedule = create(:schedule, frequency: 0, day: 5, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_friday?).to be true
    end

    it 'can be on Saturday' do
      schedule = create(:schedule, frequency: 0, day: 6, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_saturday?).to be true
    end

    it 'can be on Sunday' do
      schedule = create(:schedule, frequency: 0, day: 0, pipeline:, destination:, harvest_definitions_to_run:)

      expect(schedule.on_sunday?).to be true
    end
  end

  describe '#schedules_within_range' do
    let!(:schedule) { create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:) }
    let!(:schedule_2) { create(:schedule, frequency: 0, time: '10:30', pipeline:, destination:, harvest_definitions_to_run:) }
    let!(:schedule_3) { create(:schedule, frequency: 1, day: 1, time: '9:00', pipeline:, destination:, harvest_definitions_to_run:) }
    let!(:schedule_4) { create(:schedule, frequency: 2, bi_monthly_day_one: 2, bi_monthly_day_two: 14, time: '9:00 PM', pipeline:, destination:, harvest_definitions_to_run:) }

    it 'returns a hash of dates, with the schedules that are assigned on that date orderered by time for a given range' do
      schedule_map = Schedule.schedules_within_range('01 06 2025', '30 06 2025')

      result = {
        1062025 => {
          1030 => [schedule_2],
          1230 => [schedule],
        },
        2062025 => {
          900 => [schedule_3],
          1030 => [schedule_2],
          1230 => [schedule],
          2100 => [schedule_4]
        },
        3062025 => { 
          1030 => [schedule_2],
          1230 => [schedule]
        },
        4062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        5062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        6062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        7062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        8062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        9062025 => {
          900 => [schedule_3],
          1030 => [schedule_2],
          1230 => [schedule]
        },
        10062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        11062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        12062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        13062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        14062025 => {
          1030 => [schedule_2],
          1230 => [schedule],
          2100 => [schedule_4]
        },
        15062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        16062025 => {
          900 => [schedule_3],
          1030 => [schedule_2],
          1230 => [schedule]
        },
        17062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        18062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        19062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        20062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        21062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        22062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        23062025 => {
          900 => [schedule_3],
          1030 => [schedule_2],
          1230 => [schedule]
        },
        24062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        25062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        26062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        27062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        28062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        29062025 => {
          1030 => [schedule_2],
          1230 => [schedule]
        },
        30062025 => {
          900 => [schedule_3],
          1030 => [schedule_2]
        }
      }

      expect(schedule_map).to eq result
    end
  end
  
  describe 'validations' do
    let!(:schedule) { create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:, name: 'Pipeline Schedule') }
    it { is_expected.to validate_presence_of(:destination).with_message('must exist') }
    it { is_expected.to validate_presence_of(:frequency).with_message("can't be blank") }
    it { is_expected.to validate_presence_of(:name).with_message("can't be blank") }
    it { is_expected.to validate_presence_of(:time).with_message("can't be blank") }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.with_message('has already been taken') }

    it 'requires the harvest_definitions_to_run' do
      schedule = build(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, name: 'Harvest Definitions') 

      expect(schedule.valid?).to be false
    end

    context 'weekly' do
      subject { build(:schedule, frequency: :weekly, pipeline:, destination:, harvest_definitions_to_run:) }

      it { is_expected.to validate_presence_of(:day).with_message("can't be blank") }
    end

    context 'bi_monthly' do
      subject { build(:schedule, frequency: :bi_monthly, pipeline:, destination:, harvest_definitions_to_run:) }

      it { is_expected.to validate_presence_of(:bi_monthly_day_one).with_message("can't be blank") }
      it { is_expected.to validate_presence_of(:bi_monthly_day_two).with_message("can't be blank") }
    end

    context 'monthly' do
      subject { build(:schedule, frequency: :monthly, pipeline:, destination:, harvest_definitions_to_run:) }

      it { is_expected.to validate_presence_of(:day_of_the_month).with_message("can't be blank") }
    end

    it 'requires either a pipeline or an automation template' do
      schedule = build(:schedule, frequency: 0, time: '12:30', destination:, harvest_definitions_to_run:)

      expect(schedule.valid?).to be false
    end
  end

  describe '#cron_syntax' do
    context 'daily' do
      it 'returns a valid cron syntax for a minute and hour' do
        schedule = create(:schedule, frequency: 0, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '30 12 * * *'
      end

      it 'returns a valid cron syntax when there is just an hour' do
        schedule = create(:schedule, frequency: 0, time: '12', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '0 12 * * *'
      end

      it 'returns a valid cron syntax when the time has AM or PM' do
        schedule = create(:schedule, frequency: 0, time: '7:45PM', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '45 19 * * *'
      end

      it 'returns a valid cron syntax when the time has AM or PM' do
        schedule = create(:schedule, frequency: 0, time: '7:45 AM', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '45 07 * * *'
      end

      it 'returns a valid cron syntax when the time is a late 24 hour time' do
        schedule = create(:schedule, frequency: 0, time: '22:00', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '00 22 * * *'
      end
    end

    context 'weekly' do
      it 'returns a valid cron syntax for a particular day of the week' do
        schedule = create(:schedule, frequency: 1, day: 3, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '30 12 * * 3' 
      end
    end 

    context 'fortnightly' do
      it 'returns a valid cron syntax for a bi monthly schedule' do
        schedule = create(:schedule, frequency: 2, bi_monthly_day_one: 1, bi_monthly_day_two: 14, time: '10:45', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '45 10 1/14 * *'
      end
    end
  
    context 'monthly' do
      it 'returns a valid cron syntax for a day of the month' do
        schedule = create(:schedule, frequency: 3, day_of_the_month: 21, time: '12:30', pipeline:, destination:, harvest_definitions_to_run:)

        expect(schedule.cron_syntax).to eq '30 12 21 * *'
      end
    end
  end
end
