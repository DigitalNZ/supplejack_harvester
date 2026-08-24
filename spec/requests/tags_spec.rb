# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tags' do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe 'GET /index' do
    it 'lists the tags' do
      create(:tag, name: 'Museum')
      create(:tag, name: 'Audio')

      get tags_path

      expect(response.body).to include 'Museum'
      expect(response.body).to include 'Audio'
    end

    it 'says how many pipelines carry each tag' do
      tag = create(:tag, name: 'Museum')
      create(:pipeline).tags = [tag]
      create(:pipeline).tags = [tag]

      get tags_path

      expect(response.body).to include pipelines_path(tags: [tag.slug])
      expect(response.body).to include '2 pipelines carrying it'
    end
  end

  describe 'GET /edit' do
    it 'displays the tag being renamed' do
      tag = create(:tag, name: 'Musuem')

      get edit_tag_path(tag)

      expect(response.body).to include 'Musuem'
    end
  end

  describe 'PATCH /update' do
    it 'renames the tag' do
      tag = create(:tag, name: 'Musuem')

      patch tag_path(tag), params: { tag: { name: 'Museum' } }

      expect(tag.reload.name).to eq 'Museum'
      expect(flash[:notice]).to eq I18n.t('tags.update.success')
      expect(response).to redirect_to tags_path
    end

    # The slug follows the name, so a pipeline filtered by the tag is found under the new
    # spelling rather than the one it was tagged with.
    it 'renames the slug along with the name' do
      tag = create(:tag, name: 'Musuem')

      patch tag_path(tag), params: { tag: { name: 'Museum' } }

      expect(tag.reload.slug).to eq 'museum'
    end

    it 'keeps the tag on the pipelines carrying it' do
      tag = create(:tag, name: 'Musuem')
      pipeline = create(:pipeline)
      pipeline.tags = [tag]

      patch tag_path(tag), params: { tag: { name: 'Museum' } }

      expect(pipeline.tags.reload.map(&:name)).to eq ['Museum']
    end

    describe 'when the name cannot be saved' do
      it 'reports a name another tag already has' do
        create(:tag, name: 'Museum')
        tag = create(:tag, name: 'Musuem')

        patch tag_path(tag), params: { tag: { name: 'Museum' } }

        expect(tag.reload.name).to eq 'Musuem'
        expect(flash[:alert]).to include 'has already been taken'
      end

      it 'reports a name that reduces to nothing' do
        tag = create(:tag, name: 'Musuem')

        patch tag_path(tag), params: { tag: { name: '!!!' } }

        expect(tag.reload.name).to eq 'Musuem'
        expect(flash[:alert]).to include I18n.t('tag.validations.name_format')
      end

      it 'reports a name that is too short' do
        tag = create(:tag, name: 'Musuem')

        patch tag_path(tag), params: { tag: { name: 'a' } }

        expect(tag.reload.name).to eq 'Musuem'
        expect(flash[:alert]).to include 'too short'
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'deletes the tag' do
      tag = create(:tag, name: 'Musuem')

      expect { delete tag_path(tag) }.to change(Tag, :count).by(-1)

      expect(flash[:notice]).to eq I18n.t('tags.destroy.success', name: 'Musuem')
      expect(response).to redirect_to tags_path
    end

    it 'takes the tag off the pipelines carrying it' do
      tag = create(:tag, name: 'Musuem')
      pipeline = create(:pipeline)
      pipeline.tags = [tag, create(:tag, name: 'Audio')]

      expect { delete tag_path(tag) }.to change(PipelineTag, :count).by(-1)

      expect(pipeline.tags.reload.map(&:name)).to eq ['Audio']
    end

    it 'leaves the pipelines themselves alone' do
      tag = create(:tag)
      create(:pipeline).tags = [tag]

      expect { delete tag_path(tag) }.not_to change(Pipeline, :count)
    end
  end
end
