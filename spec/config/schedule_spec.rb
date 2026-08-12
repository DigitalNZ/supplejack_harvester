# frozen_string_literal: true

require 'rails_helper'

# Pins the live cleanup schedule. sidekiq-cron auto-loads config/schedule.yml
# on Sidekiq server startup; both jobs still honour dry_run in
# config/retention.yml.
RSpec.describe 'config/schedule.yml' do
  subject(:schedule) do
    YAML.safe_load(ERB.new(Rails.root.join('config/schedule.yml').read).result)
  end

  it 'schedules the extraction cleanup daily' do
    cron_string = schedule.dig('extraction_cleanup', 'cron')
    cron = Fugit::Cron.parse(cron_string)
    # Check frequency is daily (86400 seconds in a day)
    expect(cron.rough_frequency).to eq 86400
    # Check time is 9:15 AM (hour 9, minute 15)
    expect(cron_string).to start_with('15 9 ')
  end

  it 'maps to the extraction cleanup worker' do
    expect(schedule.dig('extraction_cleanup', 'class')).to eq 'ExtractionCleanupWorker'
  end

  it 'names a class that exists' do
    expect { schedule.dig('extraction_cleanup', 'class').constantize }.not_to raise_error
  end

  it 'uses a cron expression fugit can parse' do
    expect(Fugit::Cron.parse(schedule.dig('extraction_cleanup', 'cron'))).to be_present
  end

  it 'uses the low_priority queue' do
    expect(schedule.dig('extraction_cleanup', 'queue')).to eq 'low_priority'
  end

  it 'schedules the preprocess cleanup daily' do
    cron_string = schedule.dig('preprocess_cleanup', 'cron')
    cron = Fugit::Cron.parse(cron_string)
    # Check frequency is daily (86400 seconds in a day)
    expect(cron.rough_frequency).to eq 86400
    # Check time is 9:45 AM (hour 9, minute 45) - offset from extraction
    # cleanup so the two daily sweeps don't start at the same moment.
    expect(cron_string).to start_with('45 9 ')
  end

  it 'maps to the preprocess cleanup worker' do
    expect(schedule.dig('preprocess_cleanup', 'class')).to eq 'PreProcessCleanupWorker'
  end

  it 'names a preprocess cleanup class that exists' do
    expect { schedule.dig('preprocess_cleanup', 'class').constantize }.not_to raise_error
  end

  it 'uses a preprocess cleanup cron expression fugit can parse' do
    expect(Fugit::Cron.parse(schedule.dig('preprocess_cleanup', 'cron'))).to be_present
  end

  it 'uses the low_priority queue for preprocess cleanup' do
    expect(schedule.dig('preprocess_cleanup', 'queue')).to eq 'low_priority'
  end

  it 'lists low_priority in the staging Sidekiq queues' do
    sidekiq = YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result,
                             permitted_classes: [Symbol])
    expect(sidekiq.dig('staging', :queues)).to include('low_priority')
  end
end
