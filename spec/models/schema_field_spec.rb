require 'rails_helper'

RSpec.describe SchemaField, type: :model do
  let(:schema) { create(:schema) }
  subject { create(:schema_field, name: 'internal_identifier', schema:) }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'internal_identifier'
    end

    it { is_expected.to belong_to(:schema) }
    it { is_expected.to have_many(:schema_field_values) }
    it { is_expected.to have_many(:fields) }
  end

  describe '#kinds' do
    kinds = { dynamic: 0, fixed: 1 }

    kinds.each do |key, value|
      it "can be #{key}" do
        expect(described_class.new(kind: value).kind).to eq(key.to_s)
      end
    end
  end

  describe 'fields relationship' do
    let(:pipeline) { create(:pipeline, :figshare) }
    let(:extraction_definition) { pipeline.harvest.extraction_definition }
    let(:extraction_job) { create(:extraction_job, extraction_definition:) }
    let(:transformation_definition) { create(:transformation_definition, pipeline:, extraction_job:) }
    let!(:field) { create(:field, schema_field_id: subject.id, transformation_definition:) }

    it 'deletes associated fields when deleted' do
      expect do
        subject.destroy
      end.to change(Field, :count).by(-1)
    end
  end
end
