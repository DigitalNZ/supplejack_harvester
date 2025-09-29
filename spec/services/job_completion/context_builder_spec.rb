# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::ContextBuilder do
  let(:harvest_definition) do
    create(:harvest_definition, source_id: 'test_source', name: 'Test Source').tap do |hd|
      hd.update!(name: 'Test Source')
    end
  end
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:job) { create(:extraction_job) }
  let(:error) { StandardError.new('Test error') }

  describe '.build_context_from_args' do
    let(:args) do
      {
        error: error,
        definition: extraction_definition,
        job: job,
        details: { worker_class: 'TestWorker' }
      }
    end

    it 'builds complete context' do
      result = described_class.build_context_from_args(args)
      
      expect(result).to include(
        source_id: 'test_source',
        source_name: 'Test Source',
        process_type: :extraction,
        job_type: 'ExtractionJob',
        completion_type: :error,
        message: 'StandardError: Test error'
      )
      expect(result[:details]).to include(
        exception_class: 'StandardError',
        exception_message: 'Test error',
        job_id: job.id,
        worker_class: 'TestWorker'
      )
    end

    context 'with stop condition details' do
      let(:args) do
        {
          error: nil,
          definition: extraction_definition,
          job: job,
          details: {
            stop_condition_name: 'test_condition',
            stop_condition_type: 'user',
            worker_class: 'TestWorker'
          }
        }
      end

      it 'builds stop condition context' do
        result = described_class.build_context_from_args(args)
        
        expect(result).to include(
          completion_type: :stop_condition,
          message: "Stop condition 'test_condition' was triggered"
        )
        expect(result[:details]).to include(
          stop_condition_name: 'test_condition',
          stop_condition_type: 'user'
        )
      end
    end
  end

  describe '.determine_completion_type' do
    context 'with stop condition name' do
      let(:details) { { stop_condition_name: 'test_condition' } }

      it 'returns stop_condition' do
        result = described_class.determine_completion_type(details)
        expect(result).to eq(:stop_condition)
      end
    end

    context 'without stop condition name' do
      let(:details) { { worker_class: 'TestWorker' } }

      it 'returns error' do
        result = described_class.determine_completion_type(details)
        expect(result).to eq(:error)
      end
    end
  end

  describe '.build_final_context' do
    let(:process_info) do
      {
        source_id: 'test_source',
        source_name: 'Test Source',
        process_type: :extraction,
        job_type: 'ExtractionJob'
      }
    end
    let(:completion_type) { :error }
    let(:message) { 'Test error message' }
    let(:enhanced_details) { { worker_class: 'TestWorker' } }

    it 'builds final context hash' do
      result = described_class.build_final_context(process_info, completion_type, message, enhanced_details)
      
      expect(result).to eq({
        source_id: 'test_source',
        source_name: 'Test Source',
        process_type: :extraction,
        job_type: 'ExtractionJob',
        completion_type: :error,
        message: 'Test error message',
        details: { worker_class: 'TestWorker' }
      })
    end
  end
end
