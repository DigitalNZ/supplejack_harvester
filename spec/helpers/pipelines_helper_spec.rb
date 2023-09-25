# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelinesHelper do
  let(:pipeline) { create(:pipeline) }

  describe '#definition_help_text' do
    context 'when the harvest_definition has no extraction' do
      let(:harvest_definition) do
        create(:harvest_definition, pipeline:, extraction_definition: nil, transformation_definition: nil)
      end

      it 'returns a helpful message' do
        expect(definition_help_text(harvest_definition, 'harvest')).to eq 'Please add a harvest extraction'
      end
    end

    context 'when the harvest_definition has no transformation_definition and a completed extraction job' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:, transformation_definition: nil) }

      before do
        create(:extraction_job, extraction_definition: harvest_definition.extraction_definition, status: 'completed')
      end

      it 'returns a helpful message' do
        help_text = definition_help_text(harvest_definition, 'harvest')
        expect(help_text).to eq 'Extraction sample is complete, please add your harvest transformation'
      end
    end

    context 'when the harvest_definition does not have a transformation job an incompleted extraction job' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:, transformation_definition: nil) }

      before do
        create(:extraction_job, extraction_definition: harvest_definition.extraction_definition, status: 'running')
      end

      it 'returns a helpful message' do
        help_text = definition_help_text(harvest_definition, 'harvest')
        expect(help_text).to eq 'Extraction sample is not ready, please refresh the page to see when it is completed'
      end
    end

    context 'when the harvest_definition has a transformation definition with no fields in it' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }

      before do
        create(:extraction_job, extraction_definition: harvest_definition.extraction_definition, status: 'completed')
      end

      it 'returns a helpful message' do
        expect(definition_help_text(harvest_definition,
                                    'harvest')).to eq 'Please add fields to your transformation definition'
      end
    end

    context 'when the harvest_definition has a transformation definition with fields in it' do
      let(:harvest_definition) { create(:harvest_definition, pipeline:) }

      before do
        create(:extraction_job, extraction_definition: harvest_definition.extraction_definition, status: 'completed')
        create(
          :field,
          name: 'title',
          block: "JsonPath.new('title').on(record).first",
          transformation_definition: harvest_definition.transformation_definition
        )
      end

      it 'returns a helpful message' do
        expect(definition_help_text(harvest_definition, 'harvest')).to eq 'Your harvest is ready to run'
      end
    end
  end
end
