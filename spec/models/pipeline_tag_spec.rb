# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelineTag do
  describe 'validations' do
    subject { build(:pipeline_tag) }

    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:tag) }

    it 'stops the same tag being added to a pipeline twice' do
      pipeline_tag = create(:pipeline_tag)
      duplicate = build(:pipeline_tag, pipeline: pipeline_tag.pipeline, tag: pipeline_tag.tag)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tag_id]).to include 'has already been taken'
    end

    it 'allows the same tag on a different pipeline' do
      pipeline_tag = create(:pipeline_tag)

      expect(build(:pipeline_tag, tag: pipeline_tag.tag)).to be_valid
    end
  end
end
