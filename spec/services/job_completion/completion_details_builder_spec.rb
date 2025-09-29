# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::CompletionDetailsBuilder do
  let(:params) do
    {
      source_id: 'test_source',
      source_name: 'Test Source',
      message: 'Test message',
      job_type: 'ExtractionJob',
      process_type: :extraction,
      completion_type: :error,
      details: { worker_class: 'TestWorker' }
    }
  end

  describe '.stop_condition_details' do
    let(:params) do
      super().merge(
        details: {
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user',
          worker_class: 'TestWorker'
        }
      )
    end

    it 'builds stop condition completion hash' do
      result = described_class.stop_condition_details(params)
      
      expect(result).to include(
        source_id: 'test_source',
        source_name: 'Test Source',
        message: 'Test message',
        job_type: 'ExtractionJob',
        process_type: :extraction,
        completion_type: :stop_condition
      )
      expect(result[:details]).to include(
        stop_condition_name: 'test_condition',
        stop_condition_content: 'if count > 100',
        stop_condition_type: 'user',
        worker_class: 'TestWorker'
      )
    end
  end

  describe '.error_details' do
    it 'builds error completion hash' do
      result = described_class.error_details(params)
      
      expect(result).to include(
        source_id: 'test_source',
        source_name: 'Test Source',
        message: 'Test message',
        job_type: 'ExtractionJob',
        process_type: :extraction,
        completion_type: :error
      )
      expect(result[:details]).to eq({ worker_class: 'TestWorker' })
    end
  end

  describe '.build_completion_hash' do
    let(:details) { { worker_class: 'TestWorker' } }
    let(:completion_type) { :error }

    it 'builds completion hash with all fields' do
      result = described_class.build_completion_hash(params, details, completion_type)
      
      expect(result).to eq({
        source_id: 'test_source',
        source_name: 'Test Source',
        message: 'Test message',
        details: { worker_class: 'TestWorker' },
        job_type: 'ExtractionJob',
        process_type: :extraction,
        completion_type: :error
      })
    end
  end

  describe '.build_stop_condition_enhanced_details' do
    let(:details) do
      {
        stop_condition_name: 'test_condition',
        stop_condition_content: 'if count > 100',
        stop_condition_type: 'user',
        worker_class: 'TestWorker'
      }
    end

    it 'merges stop condition details' do
      result = described_class.build_stop_condition_enhanced_details(details)
      
      expect(result).to include(
        stop_condition_name: 'test_condition',
        stop_condition_content: 'if count > 100',
        stop_condition_type: 'user',
        worker_class: 'TestWorker'
      )
    end
  end
end
