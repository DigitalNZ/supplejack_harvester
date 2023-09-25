# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  subject { create(:user) }

  describe '#destroy' do
    it 'nullifies pipeline references of last_edited_by' do
      pipeline = create(:pipeline, last_edited_by: subject)
      expect(pipeline.last_edited_by).to eq subject
      subject.destroy
      expect(pipeline.reload.last_edited_by).to be_nil
    end

    it 'nullifies transformation_definition references of last_edited_by' do
      transformation_definition = create(:transformation_definition, last_edited_by: subject)
      expect(transformation_definition.last_edited_by).to eq subject
      subject.destroy
      expect(transformation_definition.reload.last_edited_by).to be_nil
    end

    it 'nullifies extraction_definition references of last_edited_by' do
      extraction_definition = create(:extraction_definition, last_edited_by: subject)
      expect(extraction_definition.last_edited_by).to eq subject
      subject.destroy
      expect(extraction_definition.reload.last_edited_by).to be_nil
    end
  end
end
