# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionServices::CompletionSummaryBuilder do
  let(:entry_params) do
    {
      source_id: 'test_source',
      source_name: 'Test Source',
      message: 'Test error',
      job_type: 'ExtractionJob',
      process_type: :extraction,
      completion_type: :error,
      details: { origin: 'TestWorker' }
    }
  end

  describe '.build_completion_summary' do
    it 'creates a new completion summary' do
      expect { described_class.build_completion_summary(entry_params) }
        .to change(JobCompletionSummary, :count).by(1)
    end

    it 'creates completion summary with correct attributes' do
      described_class.build_completion_summary(entry_params)
      
      summary = JobCompletionSummary.last
      expect(summary.source_id).to eq('test_source')
      expect(summary.source_name).to eq('Test Source')
      expect(summary.job_type).to eq('ExtractionJob')
      expect(summary.process_type).to eq('extraction')
      expect(summary.completion_type).to eq('error')
      expect(summary.completion_count).to eq(1)
    end

    context 'with existing completion summary' do
      before do
        create(:job_completion_summary,
               source_id: 'test_source',
               process_type: :extraction,
               job_type: 'ExtractionJob')
      end

      it 'updates existing completion summary' do
        expect { described_class.build_completion_summary(entry_params) }
          .not_to change(JobCompletionSummary, :count)
      end

      it 'increments completion count' do
        described_class.build_completion_summary(entry_params)
        
        summary = JobCompletionSummary.last
        expect(summary.completion_count).to eq(2)
      end

      it 'adds new completion entry' do
        described_class.build_completion_summary(entry_params)
        
        summary = JobCompletionSummary.last
        expect(summary.completion_entries.length).to eq(2)
        expect(summary.completion_entries.last['message']).to eq('Test error')
      end
    end
  end

  # These methods are now in CompletionSummaryManager, not CompletionSummaryBuilder
  # The CompletionSummaryBuilder only orchestrates the process
end
