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
end
