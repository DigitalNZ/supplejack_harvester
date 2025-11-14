# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletionServices::ProcessInfoBuilder do
  let(:harvest_definition) { create(:harvest_definition, source_id: 'test_source', name: 'Test Source') }
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:transformation_definition) { harvest_definition.transformation_definition }

  describe '.determine_process_info' do
    context 'with extraction definition' do
      it 'returns extraction process info' do
        result = described_class.determine_process_info(extraction_definition)
        
        expect(result).to eq({
          process_type: :extraction,
          job_type: 'ExtractionJob'
        })
      end
    end

    context 'with transformation definition' do
      it 'returns transformation process info' do
        result = described_class.determine_process_info(transformation_definition)
        
        expect(result).to eq({
          process_type: :transformation,
          job_type: 'TransformationJob'
        })
      end
    end

    context 'with invalid definition type' do
      it 'raises an error' do
        expect { described_class.determine_process_info('invalid') }
          .to raise_error('Invalid definition type: String')
      end
    end
  end

  describe '.build_extraction_process_info' do
    it 'builds correct extraction info' do
      result = described_class.build_extraction_process_info(extraction_definition)
      
      expect(result).to eq({
        process_type: :extraction,
        job_type: 'ExtractionJob'
      })
    end
  end

  describe '.build_transformation_process_info' do
    it 'builds correct transformation info' do
      result = described_class.build_transformation_process_info(transformation_definition)
      
      expect(result).to eq({
        process_type: :transformation,
        job_type: 'TransformationJob'
      })
    end
  end
end
