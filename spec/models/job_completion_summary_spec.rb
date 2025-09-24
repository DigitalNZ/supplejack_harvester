# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionSummary, type: :model do
  describe 'validations' do
    it 'validates presence of required fields' do
      summary = build(:job_completion_summary, source_id: nil, source_name: nil, job_type: nil)
      
      expect(summary).not_to be_valid
      expect(summary.errors[:source_id]).to include("can't be blank")
      expect(summary.errors[:source_name]).to include("can't be blank")
      expect(summary.errors[:job_type]).to include("can't be blank")
    end

    it 'validates completion_entries presence' do
      summary = build(:job_completion_summary, completion_entries: nil)
      
      expect(summary).not_to be_valid
      expect(summary.errors[:completion_entries]).to include("can't be blank")
    end

    it 'validates completion_count is present and non-negative' do
      summary = build(:job_completion_summary, completion_count: nil)
      expect(summary).not_to be_valid
      expect(summary.errors[:completion_count]).to include("can't be blank")

      summary = build(:job_completion_summary, completion_count: -1)
      expect(summary).not_to be_valid
      expect(summary.errors[:completion_count]).to include("must be greater than or equal to 0")
    end

    it 'validates uniqueness of source_id scoped to process_type and job_type' do
      create(:job_completion_summary, source_id: 'test_id', process_type: 'extraction', job_type: 'ExtractionJob')
      
      duplicate = build(:job_completion_summary, source_id: 'test_id', process_type: 'extraction', job_type: 'ExtractionJob')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_id]).to include("has already been taken")
    end
  end

  describe 'enums' do
    it 'defines completion_type enum' do
      expect(JobCompletionSummary.completion_types).to eq({ 'error' => 0, 'stop_condition' => 1 })
    end

    it 'defines process_type enum' do
      expect(JobCompletionSummary.process_types).to eq({ 'extraction' => 0, 'transformation' => 1 })
    end
  end

  describe 'scopes' do
    it 'has recent_completions scope' do
      create(:job_completion_summary, last_occurred_at: 2.days.ago)
      recent = create(:job_completion_summary, last_occurred_at: 1.day.ago)
      
      expect(JobCompletionSummary.recent_completions.first).to eq(recent)
    end
  end

  describe 'defaults' do
    it 'sets default values for new records' do
      summary = JobCompletionSummary.new
      
      expect(summary.completion_entries).to eq([])
      expect(summary.completion_count).to eq(0)
    end
  end

  describe '.log_completion' do
    let(:params) do
      {
        source_id: 'test_source',
        source_name: 'Test Source',
        message: 'Test error',
        job_type: 'ExtractionJob',
        process_type: :extraction,
        completion_type: :error,
        details: { worker_class: 'TestWorker' }
      }
    end

    it 'creates a new completion summary' do
      expect { JobCompletionSummary.log_completion(params) }.to change(JobCompletionSummary, :count).by(1)
    end

    it 'updates existing completion summary' do
      JobCompletionSummary.log_completion(params)
      
      expect { JobCompletionSummary.log_completion(params) }.not_to change(JobCompletionSummary, :count)
      
      summary = JobCompletionSummary.last
      expect(summary.completion_count).to eq(2)
    end
  end
end
