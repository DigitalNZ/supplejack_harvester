# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobCompletion::ProcessInfoBuilder do
  let(:harvest_definition) do
    create(:harvest_definition, source_id: 'test_source', name: 'Test Source').tap do |hd|
      hd.update!(name: 'Test Source')
    end
  end
  let(:extraction_definition) { harvest_definition.extraction_definition }
  let(:transformation_definition) { create(:transformation_definition, harvest_definitions: [harvest_definition]) }

  describe '.determine_process_info' do
    context 'with extraction definition' do
      it 'returns extraction process info' do
        result = described_class.determine_process_info(extraction_definition)
        
        expect(result).to include(
          process_type: :extraction,
          job_type: 'ExtractionJob',
          source_id: 'test_source',
          source_name: 'Test Source'
        )
      end
    end

    context 'with transformation definition' do
      it 'returns transformation process info' do
        result = described_class.determine_process_info(transformation_definition)
        
        expect(result).to include(
          process_type: :transformation,
          job_type: 'TransformationJob',
          source_id: 'test_source',
          source_name: 'Test Source'
        )
      end
    end

    context 'with invalid definition type' do
      it 'raises an error' do
        expect { described_class.determine_process_info('invalid') }
          .to raise_error('Invalid definition type: String')
      end
    end

    context 'with missing harvest definition' do
      let(:empty_definition) { create(:extraction_definition) }
      
      before { empty_definition.harvest_definitions.clear }

      it 'returns unknown values' do
        result = described_class.determine_process_info(empty_definition)
        
        expect(result).to include(
          source_id: 'unknown',
          source_name: 'unknown'
        )
      end
    end
  end

  describe '.build_extraction_process_info' do
    it 'builds correct extraction info' do
      result = described_class.build_extraction_process_info(extraction_definition)
      
      expect(result).to eq({
        process_type: :extraction,
        job_type: 'ExtractionJob',
        source_id: 'test_source',
        source_name: 'Test Source'
      })
    end
  end

  describe '.build_transformation_process_info' do
    it 'builds correct transformation info' do
      result = described_class.build_transformation_process_info(transformation_definition)
      
      expect(result).to eq({
        process_type: :transformation,
        job_type: 'TransformationJob',
        source_id: 'test_source',
        source_name: 'Test Source'
      })
    end
  end
end
