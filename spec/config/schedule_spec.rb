# frozen_string_literal: true

require 'rails_helper'

# The schedule is parked as schedule.disabled.yml while the retention policy
# is verified by hand — sidekiq-cron only auto-loads config/schedule.yml.
# These examples keep pinning the content that goes live when it is renamed
# back.
RSpec.describe 'config/schedule.disabled.yml' do
  subject(:schedule) do
    YAML.safe_load(ERB.new(Rails.root.join('config/schedule.disabled.yml').read).result)
  end

  it 'schedules the extraction cleanup nightly' do
    cron_string = schedule.dig('extraction_cleanup', 'cron')
    cron = Fugit::Cron.parse(cron_string)
    # Check frequency is daily (86400 seconds in a day)
    expect(cron.rough_frequency).to eq 86400
    # Check time is 2 AM (hour 2, minute 0)
    expect(cron_string).to start_with('0 2 ')
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

  it 'schedules the preprocess cleanup nightly' do
    cron_string = schedule.dig('preprocess_cleanup', 'cron')
    cron = Fugit::Cron.parse(cron_string)
    # Check frequency is daily (86400 seconds in a day)
    expect(cron.rough_frequency).to eq 86400
    # Check time is 2:30 AM (hour 2, minute 30) - offset from extraction
    # cleanup so the two nightly sweeps don't start at the same moment.
    expect(cron_string).to start_with('30 2 ')
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
end
