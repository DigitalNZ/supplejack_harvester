require 'rails_helper'

RSpec.describe Transformation::FieldExecution do
  let(:transformation_definition) { create(:transformation_definition) }
  let(:harvest_definition) { create(:harvest_definition, transformation_definition: transformation_definition) }
  let(:harvest_job) { create(:harvest_job, harvest_definition: harvest_definition) }
  let(:field) { create(:field, transformation_definition: transformation_definition, block: "record.undefined_method") }
  let(:extracted_record) { double('extracted_record') }

  describe '#execute' do
    context 'when field execution fails' do
      it 'creates a JobCompletionSummary' do
        execution = described_class.new(field)
        
        expect { execution.execute(extracted_record) }.to change(JobCompletionSummary, :count).by(1)
      end
    end
  end
end
