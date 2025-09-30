# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::CompletionSummaryManager do
  let(:entry_params) do
    {
      source_id: 'test_source',
      source_name: 'Test Source',
      process_type: :extraction,
      job_type: 'ExtractionJob'
    }
  end

  describe '.find_or_create_completion_summary' do
    it 'finds existing completion summary' do
      existing = create(:job_completion_summary,
                       source_id: 'test_source',
                       process_type: :extraction,
                       job_type: 'ExtractionJob')
      
      result = described_class.find_or_create_completion_summary(entry_params, :extraction, 'ExtractionJob')
      expect(result).to eq(existing)
    end

    it 'creates new completion summary when none exists' do
      result = described_class.find_or_create_completion_summary(entry_params, :extraction, 'ExtractionJob')
      expect(result).to be_a(JobCompletionSummary)
      expect(result).to be_new_record
    end

    it 'initializes with correct attributes' do
      result = described_class.find_or_create_completion_summary(entry_params, :extraction, 'ExtractionJob')
      
      expect(result.source_id).to eq('test_source')
      expect(result.process_type).to eq('extraction')
      expect(result.job_type).to eq('ExtractionJob')
    end
  end

  describe '.update_completion_summary' do
    let(:completion_summary) { create(:job_completion_summary) }
    let(:completion_entry) do
      {
        'message' => 'Test error',
        'details' => { 'worker_class' => 'TestWorker' },
        'timestamp' => Time.current.iso8601
      }
    end

    it 'updates completion summary attributes' do
      described_class.update_completion_summary(
        completion_summary, entry_params, completion_entry, :error
      )
      
      expect(completion_summary.source_name).to eq('Test Source')
      expect(completion_summary.completion_type).to eq('error')
      expect(completion_summary.completion_count).to eq(2)
    end

    it 'adds completion entry to entries array' do
      original_count = completion_summary.completion_entries.length
      
      described_class.update_completion_summary(
        completion_summary, entry_params, completion_entry, :error
      )
      
      expect(completion_summary.completion_entries.length).to eq(original_count + 1)
      expect(completion_summary.completion_entries.last).to eq(completion_entry)
    end

    it 'updates last_completed_at timestamp' do
      before_time = Time.current
      described_class.update_completion_summary(
        completion_summary, entry_params, completion_entry, :error
      )
      after_time = Time.current
      
      expect(completion_summary.last_completed_at).to be_between(before_time, after_time)
    end

    it 'saves the completion summary' do
      expect(completion_summary).to receive(:save!)
      described_class.update_completion_summary(
        completion_summary, entry_params, completion_entry, :error
      )
    end
  end
end
