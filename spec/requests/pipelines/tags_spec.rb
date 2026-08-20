# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pipelines::Tags' do
  let(:user)     { create(:user) }
  let(:pipeline) { create(:pipeline) }

  before { sign_in(user) }

  describe 'PATCH /update' do
    it 'tags the pipeline with an existing tag' do
      production = create(:tag, name: 'Production')

      patch pipeline_tags_path(pipeline), params: { tag_names: ['Production'] }

      expect(pipeline.tags.reload).to contain_exactly production
      expect(flash[:notice]).to eq I18n.t('pipelines.tags.update.success')
      expect(response).to redirect_to pipeline_path(pipeline)
    end

    it 'creates a tag that does not exist yet' do
      expect { patch pipeline_tags_path(pipeline), params: { tag_names: ['Museum'] } }
        .to change(Tag, :count).by(1)

      expect(pipeline.tags.reload.map(&:name)).to eq ['Museum']
    end

    it 'adds several tags at once' do
      patch pipeline_tags_path(pipeline), params: { tag_names: %w[Museum Audio] }

      expect(pipeline.tags.reload.map(&:name)).to contain_exactly 'Museum', 'Audio'
    end

    # The editor submits the set the pipeline should end up with, so a tag left out of
    # that set is a tag being taken off.
    it 'replaces the tags rather than adding to them' do
      pipeline.tags = [create(:tag, name: 'Production'), create(:tag, name: 'Audio')]

      patch pipeline_tags_path(pipeline), params: { tag_names: ['Audio'] }

      expect(pipeline.tags.reload.map(&:name)).to eq ['Audio']
    end

    it 'takes every tag off when none are submitted' do
      pipeline.tags = [create(:tag, name: 'Production')]

      patch pipeline_tags_path(pipeline)

      expect(pipeline.tags.reload).to be_empty
    end

    it 'leaves the tag it already has alone rather than recreating it' do
      production = create(:tag, name: 'Production')
      pipeline.tags = [production]

      expect { patch pipeline_tags_path(pipeline), params: { tag_names: ['Production'] } }
        .not_to change(PipelineTag, :count)

      expect(pipeline.tags.reload).to contain_exactly production
    end

    describe 'when a name cannot be saved' do
      it 'reports the reason and changes nothing' do
        pipeline.tags = [create(:tag, name: 'Production')]

        patch pipeline_tags_path(pipeline), params: { tag_names: ['Production', '!!!'] }

        expect(pipeline.tags.reload.map(&:name)).to eq ['Production']
        expect(flash[:alert]).to include I18n.t('tag.validations.name_format')
      end

      it 'reports a name that is too long' do
        patch pipeline_tags_path(pipeline), params: { tag_names: ['a' * 51] }

        expect(pipeline.tags.reload).to be_empty
        expect(flash[:alert]).to include 'too long'
      end
    end
  end
end
