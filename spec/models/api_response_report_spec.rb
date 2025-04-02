# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiResponseReport do
  subject { build(:api_response_report) }

  it { is_expected.to belong_to(:automation_step) }
  it { is_expected.to validate_presence_of(:status) }

  describe '#display_name' do
    it 'returns a formatted name with the ID' do
      api_response_report = create(:api_response_report)
      expect(api_response_report.display_name).to eq("API Response #{api_response_report.id}")
    end
  end

  describe '#successful?' do
    it 'returns true when status is completed' do
      api_response_report = build(:api_response_report, status: 'completed')
      expect(api_response_report.successful?).to be true
    end

    it 'returns false when status is not completed' do
      api_response_report = build(:api_response_report, status: 'errored')
      expect(api_response_report.successful?).to be false
    end
  end

  describe '#failed?' do
    it 'returns true when status is errored' do
      api_response_report = build(:api_response_report, status: 'errored')
      expect(api_response_report.failed?).to be true
    end

    it 'returns false when status is not errored' do
      api_response_report = build(:api_response_report, status: 'completed')
      expect(api_response_report.failed?).to be false
    end
  end

  describe '#queued?' do
    it 'returns true when status is queued' do
      api_response_report = build(:api_response_report, status: 'queued')
      expect(api_response_report.queued?).to be true
    end

    it 'returns false when status is not queued' do
      api_response_report = build(:api_response_report, status: 'completed')
      expect(api_response_report.queued?).to be false
    end
  end
end 