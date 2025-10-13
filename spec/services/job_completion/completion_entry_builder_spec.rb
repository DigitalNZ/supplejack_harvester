# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::CompletionEntryBuilder do
  let(:params) do
    {
      source_id: 'test_source',
      source_name: 'Test Source',
      message: 'Test error',
      job_type: 'ExtractionJob',
      process_type: :extraction,
      completion_type: :error,
      details: { origin: 'TestWorker', job_id: '123' }
    }
  end

  describe '.build_completion_entry' do
    it 'builds completion entry with all required fields' do
      completion_entry, process_type, completion_type, job_type, source_id, source_name = 
        described_class.build_completion_entry(params)
      
      expect(completion_entry).to include(
        message: 'Test error',
        details: { origin: 'TestWorker', job_id: '123' },
        timestamp: be_a(String),
        origin: 'TestWorker',
        job_id: '123',
        context: {}
      )
      expect(process_type).to eq(:extraction)
      expect(completion_type).to eq(:error)
      expect(job_type).to eq('ExtractionJob')
      expect(source_id).to eq('test_source')
      expect(source_name).to eq('Test Source')
    end

    context 'with stack trace in details' do
      let(:params) do
        super().merge(
          details: {
            origin: 'TestWorker',
            stack_trace: ['line1', 'line2']
          }
        )
      end

      it 'includes stack trace in completion entry' do
        completion_entry, = described_class.build_completion_entry(params)
        
        expect(completion_entry[:stack_trace]).to eq(['line1', 'line2'])
      end
    end

    context 'with context in details' do
      let(:params) do
        super().merge(
          details: {
            origin: 'TestWorker',
            context: { test: true }
          }
        )
      end

      it 'includes context in completion entry' do
        completion_entry, = described_class.build_completion_entry(params)
        
        expect(completion_entry[:context]).to eq({ test: true })
      end
    end
  end

  describe '.build_completion_entry_hash' do
    let(:message) { 'Test error message' }
    let(:details) { { origin: 'TestWorker', job_id: '123' } }

    it 'builds completion entry hash with timestamp' do
      result = described_class.build_completion_entry_hash(message, details)
      
      expect(result).to include(
        message: 'Test error message',
        details: { origin: 'TestWorker', job_id: '123' },
        origin: 'TestWorker',
        job_id: '123',
        context: {}
      )
      expect(result[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    context 'with empty details' do
      let(:details) { {} }

      it 'builds completion entry with empty context' do
        result = described_class.build_completion_entry_hash(message, details)
        
        expect(result[:context]).to eq({})
        expect(result[:details]).to eq({})
      end
    end
  end
end
