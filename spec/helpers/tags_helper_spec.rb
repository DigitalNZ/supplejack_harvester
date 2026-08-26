# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TagsHelper do
  describe '#tag_labels' do
    it 'draws every tag when there are few enough of them' do
      tags = [create(:tag, name: 'Dev'), create(:tag, name: 'Prod')]

      expect(helper.tag_labels(tags, limit: 3)).to include 'Dev', 'Prod'
    end

    it 'draws each tag in the colour it carries' do
      tags = [create(:tag, name: 'Prod', color: :unmatched_beauty)]

      expect(helper.tag_labels(tags, limit: 3)).to include 'tag--unmatched-beauty'
    end

    it 'counts the tags it has no room for rather than dropping them' do
      tags = Array.new(5) { |n| create(:tag, name: "Tag #{n}") }

      labels = helper.tag_labels(tags, limit: 3)

      expect(labels).to include 'Tag 0', 'Tag 1', 'Tag 2', '+2'
      expect(labels).not_to include '>Tag 3<'
    end

    # Nothing is hidden outright: the count says which tags it stands for.
    it 'names the tags behind the count' do
      tags = Array.new(5) { |n| create(:tag, name: "Tag #{n}") }

      expect(helper.tag_labels(tags, limit: 3)).to include 'title="Tag 3, Tag 4"'
    end

    it 'is empty for a pipeline with no tags' do
      expect(helper.tag_labels([], limit: 3)).to eq ''
    end
  end
end
