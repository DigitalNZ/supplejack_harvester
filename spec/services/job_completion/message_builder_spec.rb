# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::MessageBuilder do
  describe '.build_message' do
    context 'with stop condition details' do
      let(:details) do
        {
          stop_condition_name: 'test_condition',
          stop_condition_type: 'user'
        }
      end

      it 'builds stop condition message' do
        result = described_class.build_message(nil, details)
        expect(result).to eq("Stop condition 'test_condition' was triggered")
      end
    end

    context 'with field name in details' do
      let(:details) { { field_name: 'test_field' } }
      let(:error) { StandardError.new('Test error') }

      it 'builds transformation failure message' do
        result = described_class.build_message(error, details)
        expect(result).to eq("Transformation failed 'test_field'")
      end
    end

    context 'with error only' do
      let(:error) { StandardError.new('Test error') }
      let(:details) { {} }

      it 'builds error message' do
        result = described_class.build_message(error, details)
        expect(result).to eq('StandardError: Test error')
      end
    end

    context 'with no error and no special details' do
      it 'builds unknown error message' do
        result = described_class.build_message(nil, {})
        expect(result).to eq('Unknown error occurred')
      end
    end
  end

  describe '.build_stop_condition_message' do
    context 'with user stop condition' do
      let(:details) do
        {
          stop_condition_name: 'user_condition',
          stop_condition_type: 'user'
        }
      end

      it 'builds user stop condition message' do
        result = described_class.build_stop_condition_message(details)
        expect(result).to eq("Stop condition 'user_condition' was triggered")
      end
    end

    context 'with system stop condition' do
      let(:details) do
        {
          stop_condition_name: 'system_condition',
          stop_condition_type: 'system'
        }
      end

      it 'builds system stop condition message' do
        result = described_class.build_stop_condition_message(details)
        expect(result).to eq("System stop condition 'system_condition' was triggered")
      end
    end
  end

  describe '.build_error_message' do
    context 'with error' do
      let(:error) { StandardError.new('Test error message') }

      it 'builds error message with class and message' do
        result = described_class.build_error_message(error)
        expect(result).to eq('StandardError: Test error message')
      end
    end

    context 'with nil error' do
      it 'builds unknown error message' do
        result = described_class.build_error_message(nil)
        expect(result).to eq('Unknown error occurred')
      end
    end
  end
end
