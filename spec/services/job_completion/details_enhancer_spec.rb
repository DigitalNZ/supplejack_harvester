# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::DetailsEnhancer do
  let(:job) { create(:extraction_job) }
  let(:error) { StandardError.new('Test error') }
  let(:details) { { worker_class: 'TestWorker' } }

  describe '.build_enhanced_details' do
    context 'with error, job, and details' do
      it 'enhances details with all information' do
        result = described_class.build_enhanced_details(error, job, details)
        
        expect(result).to include(
          exception_class: 'StandardError',
          exception_message: 'Test error',
          stack_trace: error.backtrace&.first(20),
          job_id: job.id,
          worker_class: 'TestWorker'
        )
      end
    end

    context 'with stop condition details' do
      let(:details) do
        {
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user',
          worker_class: 'TestWorker'
        }
      end

      it 'includes stop condition information' do
        result = described_class.build_enhanced_details(nil, job, details)
        
        expect(result).to include(
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user',
          job_id: job.id,
          worker_class: 'TestWorker'
        )
      end
    end

    context 'with nil error' do
      it 'does not include error details' do
        result = described_class.build_enhanced_details(nil, job, details)
        
        expect(result).not_to have_key(:exception_class)
        expect(result).not_to have_key(:exception_message)
        expect(result).not_to have_key(:stack_trace)
      end
    end

    context 'with nil job' do
      it 'does not include job details' do
        result = described_class.build_enhanced_details(error, nil, details)
        
        expect(result[:job_id]).to be_nil
      end
    end
  end

  describe '.add_error_details' do
    it 'adds error information to details' do
      enhanced_details = {}
      described_class.add_error_details(enhanced_details, error)
      
      expect(enhanced_details).to include(
        exception_class: 'StandardError',
        exception_message: 'Test error',
        stack_trace: error.backtrace&.first(20)
      )
    end
  end

  describe '.add_job_details' do
    it 'adds job information to details' do
      enhanced_details = {}
      described_class.add_job_details(enhanced_details, job)
      
      expect(enhanced_details).to include(job_id: job.id)
    end

    context 'with nil job' do
      it 'adds nil job_id' do
        enhanced_details = {}
        described_class.add_job_details(enhanced_details, nil)
        
        expect(enhanced_details).to include(job_id: nil)
      end
    end
  end

  describe '.add_stop_condition_details' do
    context 'with stop condition details' do
      let(:details) do
        {
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user'
        }
      end

      it 'adds stop condition information' do
        enhanced_details = {}
        described_class.add_stop_condition_details(enhanced_details, details)
        
        expect(enhanced_details).to include(
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user'
        )
      end
    end

    context 'without stop condition details' do
      it 'does not add stop condition information' do
        enhanced_details = {}
        described_class.add_stop_condition_details(enhanced_details, {})
        
        expect(enhanced_details).to be_empty
      end
    end
  end

  describe '.add_additional_details' do
    it 'adds remaining details excluding stop condition fields' do
      details = {
        worker_class: 'TestWorker',
        pipeline_job_id: '123',
        stop_condition_name: 'test',
        stop_condition_content: 'content',
        stop_condition_type: 'user'
      }
      
      enhanced_details = {}
      described_class.add_additional_details(enhanced_details, details)
      
      expect(enhanced_details).to include(
        worker_class: 'TestWorker',
        pipeline_job_id: '123'
      )
      expect(enhanced_details).not_to have_key(:stop_condition_name)
      expect(enhanced_details).not_to have_key(:stop_condition_content)
      expect(enhanced_details).not_to have_key(:stop_condition_type)
    end
  end
end
