# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/supplejack/job_completion/logger'

RSpec.describe JobCompletion::Logger do
  let(:harvest_definition) do
    create(:harvest_definition, source_id: 'test_source', name: 'Test Source').tap do |hd|
      # Ensure the name is set correctly by updating it after creation
      hd.update!(name: 'Test Source')
    end
  end
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:extraction_job) { create(:extraction_job, extraction_definition: extraction_definition) }

  describe '.log_completion' do
    context 'with valid arguments' do
      let(:valid_args) do
        {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: extraction_definition,
          job: extraction_job
        }
      end

      it 'successfully logs completion' do
        expect { described_class.log_completion(valid_args) }.to change(JobCompletionSummary, :count).by(1)
      end

      it 'creates completion summary with correct attributes' do
        described_class.log_completion(valid_args)
        
        summary = JobCompletionSummary.last
        expect(summary.source_id).to eq('test_source')
        expect(summary.source_name).to eq('Test Source')
        expect(summary.process_type).to eq('extraction')
        expect(summary.job_type).to eq('ExtractionJob')
        expect(summary.completion_type).to eq('error')
      end
    end

    context 'with stop condition details' do
      let(:stop_condition_args) do
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

      it 'logs stop condition completion' do
        described_class.log_completion(stop_condition_args)
        
        summary = JobCompletionSummary.last
        expect(summary.completion_type).to eq('stop_condition')
        expect(summary.completion_entries.first['message']).to include("Stop condition 'test_condition' was triggered")
      end
    end

    context 'error handling' do
      it 'handles nil definition gracefully' do
        bad_args = {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: nil,
          job: extraction_job
        }

        expect(Rails.logger).to receive(:error).with("Failed to log completion: Invalid definition type: NilClass")
        expect { described_class.log_completion(bad_args) }.not_to raise_error
      end

      it 'handles invalid definition type' do
        bad_args = {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: 'invalid_type',
          job: extraction_job
        }

        expect(Rails.logger).to receive(:error).with("Failed to log completion: Invalid definition type: String")
        expect { described_class.log_completion(bad_args) }.not_to raise_error
      end

      it 'handles missing harvest definition' do
        empty_extraction_definition = create(:extraction_definition)
        empty_extraction_definition.harvest_definitions.clear
        
        bad_args = {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: empty_extraction_definition,
          job: extraction_job
        }

        expect { described_class.log_completion(bad_args) }.not_to raise_error
        
        summary = JobCompletionSummary.last
        expect(summary.source_id).to eq('unknown')
        expect(summary.source_name).to eq('unknown')
      end

      it 'handles nil error gracefully' do
        args_without_error = {
          worker_class: 'TestWorker',
          error: nil,
          definition: extraction_definition,
          job: extraction_job
        }

        expect { described_class.log_completion(args_without_error) }.not_to raise_error
        
        summary = JobCompletionSummary.last
        expect(summary.completion_entries.first['message']).to eq('Unknown error occurred')
      end

      it 'handles nil job gracefully' do
        args_without_job = {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: extraction_definition,
          job: nil
        }

        expect { described_class.log_completion(args_without_job) }.not_to raise_error
        
        summary = JobCompletionSummary.last
        expect(summary.completion_entries.first['details']['job_id']).to be_nil
      end

      it 'handles empty details hash' do
        args_with_empty_details = {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: extraction_definition,
          job: extraction_job,
          details: {}
        }

        expect { described_class.log_completion(args_with_empty_details) }.not_to raise_error
      end

      it 'handles CompletionSummaryBuilder errors' do
        test_args = {
          worker_class: 'TestWorker',
          error: StandardError.new('Test error'),
          definition: extraction_definition,
          job: extraction_job
        }

        allow(JobCompletion::CompletionSummaryBuilder).to receive(:build_completion_summary).and_raise(StandardError.new('Database error'))

        expect(Rails.logger).to receive(:error).with("Failed to log completion: Database error")
        
        expect { described_class.log_completion(test_args) }.not_to raise_error
      end
    end
  end
end
