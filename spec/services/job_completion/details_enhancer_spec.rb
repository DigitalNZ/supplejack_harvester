# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::DetailsEnhancer do
  let(:job) { create(:extraction_job) }
  let(:error) { StandardError.new('Test error') }
  let(:details) { { origin: 'TestWorker' } }

  describe '.build_enhanced_details' do
    context 'with error, job, and details' do
      it 'enhances details with all information' do
        result = described_class.build_enhanced_details(error, job, details, 'TestWorker')
        
        expect(result).to include(
          exception_class: 'StandardError',
          exception_message: 'Test error',
          stack_trace: error.backtrace&.first(20),
          job_id: job.id,
          origin: 'TestWorker'
        )
      end
    end

    context 'with stop condition details' do
      let(:details) do
        {
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user',
          origin: 'TestWorker'
        }
      end

      it 'includes stop condition information' do
        result = described_class.build_enhanced_details(nil, job, details, 'TestWorker')
        
        expect(result).to include(
          stop_condition_name: 'test_condition',
          stop_condition_content: 'if count > 100',
          stop_condition_type: 'user',
          job_id: job.id,
          origin: 'TestWorker'
        )
      end
    end

    context 'with nil error' do
      it 'does not include error details' do
        result = described_class.build_enhanced_details(nil, job, details, 'TestWorker')
        
        expect(result).not_to have_key(:exception_class)
        expect(result).not_to have_key(:exception_message)
        expect(result).not_to have_key(:stack_trace)
      end
    end

    context 'with nil job' do
      it 'does not include job details' do
        result = described_class.build_enhanced_details(error, nil, {}, 'TestWorker')
        
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
        origin: 'TestWorker',
        pipeline_job_id: '123',
        stop_condition_name: 'test',
        stop_condition_content: 'content',
        stop_condition_type: 'user'
      }
      
      enhanced_details = {}
      described_class.add_additional_details(enhanced_details, details)
      
      expect(enhanced_details).to include(
        origin: 'TestWorker',
        pipeline_job_id: '123'
      )
      expect(enhanced_details).not_to have_key(:stop_condition_name)
      expect(enhanced_details).not_to have_key(:stop_condition_content)
      expect(enhanced_details).not_to have_key(:stop_condition_type)
    end
  end
end
