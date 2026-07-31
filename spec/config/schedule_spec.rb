# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/schedule.yml' do
  subject(:schedule) do
    YAML.safe_load(ERB.new(Rails.root.join('config/schedule.yml').read).result)
  end

  it 'schedules the extraction cleanup nightly' do
    cron_string = schedule.dig('extraction_cleanup', 'cron')
    # Should run at 2 AM (hour 2, minute 0)
    expect(cron_string).to start_with('0 2 ')
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
end
