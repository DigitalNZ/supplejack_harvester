# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Field do
  let(:pipeline) { create(:pipeline, :figshare) }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let(:extraction_job) { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition) { create(:transformation_definition, pipeline:, extraction_job:) }
  let(:subject) { create(:field, transformation_definition:) }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'title'
    end

    it 'has a block' do
      expect(subject.block).to eq "JsonPath.new('title').on(record).first"
    end

    it 'belongs to a transformation' do
      expect(subject.transformation_definition).to eq transformation_definition
    end

    it { should have_many(:schema_field_values) }
  end

  describe 'kinds' do
    let(:field)        { create(:field, transformation_definition:) }
    let(:reject_field) { create(:field, kind: 1, transformation_definition:) }
    let(:delete_field) { create(:field, kind: 2, transformation_definition:) }

    it 'can be a field' do
      expect(field.field?).to be true
    end

    it 'can be a reject_if field' do
      expect(reject_field.reject_if?).to be true
    end

    it 'can be a delete_if field' do
      expect(delete_field.delete_if?).to be true
    end
  end

  context 'when associated with a schema field' do
    let(:schema)             { create(:schema) }
    let(:schema_field)       { create(:schema_field, schema:, name: 'document_source', kind: 'fixed') }
    let(:schema_field_value) { create(:schema_field_value, value: 'external', schema_field:) }
    let(:schema_field_value_two) { create(:schema_field_value, value: 'internal', schema_field:) }

    let(:dynamic_schema_field) { create(:schema_field, schema:, name: 'internal_identifier', kind: 'dynamic') }

    let(:fixed_schema_field) { create(:schema_field, schema:, name: 'test', kind: 'fixed') }

    let(:field)              { create(:field, transformation_definition:, schema_field:, name: 'test field') }
    let(:custom_field)       { create(:field, transformation_definition:, name: 'hello') }
    let(:dynamic_field)      { create(:field, transformation_definition:, schema_field: dynamic_schema_field, block: 'Dynamic Block') }
    let(:fixed_field)        { create(:field, transformation_definition:, schema_field: fixed_schema_field) }

    describe 'name' do
      it 'gets its name from a schema field' do
        expect(field.name).to eq 'document_source'
      end
    end

    describe 'block' do
      it 'uses its own block when the schema field is type kind dynamic' do
        expect(dynamic_field.block).to eq 'Dynamic Block'
      end

      it 'returns '' if the schema field is type fixed but it has no values' do
        expect(fixed_field.block).to eq ''
      end

      it 'gets its block from a schema field value when the schema field is kind fixed' do
        field.schema_field_values << schema_field_value
        field.save

        expect(field.block).to eq "\"external\""
      end

      it 'returns a block that is an array of the selected fixed values when multiple fixed values have been chosen' do
        field.schema_field_values << schema_field_value
        field.schema_field_values << schema_field_value_two
        field.save

        expect(field.block).to eq "[\"external\", \"internal\"]"
      end
    end

    describe '#schema?' do
      it 'returns true when it is associated with a schema field' do
        expect(field.schema?).to eq true
      end

      it 'returns false when it is not associated with a schema field' do
        expect(custom_field.schema?).to eq false
      end
    end
  end
end
