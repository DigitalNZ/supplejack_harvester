# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionSummary, 'Integration with Services' do
  describe '.log_completion' do
    let(:params) do
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

    it 'creates completion summary using services' do
      expect { JobCompletionSummary.log_completion(params) }.to change(JobCompletionSummary, :count).by(1)
      
      summary = JobCompletionSummary.last
      expect(summary.source_id).to eq('test_source')
      expect(summary.completion_type).to eq('error')
      expect(summary.completion_entries.first['message']).to eq('Test error')
    end

    context 'with stop condition' do
      let(:params) do
        super().merge(
          completion_type: :stop_condition,
          details: {
            stop_condition_name: 'test_condition',
            stop_condition_content: 'if count > 100',
            stop_condition_type: 'user',
            origin: 'TestWorker'
          }
        )
      end

      it 'creates stop condition completion summary' do
        JobCompletionSummary.log_completion(params)
        
        summary = JobCompletionSummary.last
        expect(summary.completion_type).to eq('stop_condition')
        expect(summary.completion_entries.first['details']).to include(
          'stop_condition_name' => 'test_condition',
          'stop_condition_content' => 'if count > 100',
          'stop_condition_type' => 'user'
        )
      end
    end
  end
end
