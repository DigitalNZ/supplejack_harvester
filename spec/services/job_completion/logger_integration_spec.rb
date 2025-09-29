# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::Logger, 'Integration' do
  let(:harvest_definition) do
    create(:harvest_definition, source_id: 'test_source', name: 'Test Source').tap do |hd|
      hd.update!(name: 'Test Source')
    end
  end
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:extraction_job) { create(:extraction_job, extraction_definition: extraction_definition) }

  describe '.log_completion' do
    context 'with error completion' do
      let(:args) do
        {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: extraction_definition,
          job: extraction_job
        }
      end

      it 'successfully logs completion using all services' do
        expect { described_class.log_completion(args) }.to change(JobCompletionSummary, :count).by(1)
        
        summary = JobCompletionSummary.last
        expect(summary.source_id).to eq('test_source')
        expect(summary.source_name).to eq('Test Source')
        expect(summary.process_type).to eq('extraction')
        expect(summary.job_type).to eq('ExtractionJob')
        expect(summary.completion_type).to eq('error')
        expect(summary.completion_entries.first['message']).to eq('StandardError: Test error')
      end
    end

    context 'with stop condition completion' do
      let(:args) do
        {
          worker_class: 'TestWorker',
          definition: extraction_definition,
          job: extraction_job,
          details: {
            stop_condition_name: 'test_condition',
            stop_condition_content: 'if records.count > 100',
            stop_condition_type: 'user'
          }
        }
      end

      it 'successfully logs stop condition completion' do
        expect { described_class.log_completion(args) }.to change(JobCompletionSummary, :count).by(1)
        
        summary = JobCompletionSummary.last
        expect(summary.completion_type).to eq('stop_condition')
        expect(summary.completion_entries.first['message']).to include("Stop condition 'test_condition' was triggered")
      end
    end

    context 'when service raises error' do
      let(:args) do
        {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: extraction_definition,
          job: extraction_job
        }
      end

      before do
        allow(JobCompletion::ContextBuilder).to receive(:build_context_from_args)
          .and_raise(StandardError.new('Service error'))
      end

      it 'logs error and does not raise' do
        expect(Rails.logger).to receive(:error).with("Failed to log completion: Service error")
        
        expect { described_class.log_completion(args) }.not_to raise_error
      end
    end
  end
end
