# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  # The two sentences a list shows: what its filters left, beside the filters, and where
  # the current page sits, beside the pagination.
  describe '#list_summary' do
    it 'says how many there are when the filters left everything' do
      create_list(:pipeline, 3)

      expect(list_summary(Pipeline.page(1), 3, 'pipeline')).to eq '3 pipelines'
    end

    it 'compares what is left against everything when the filters cut some out' do
      create_list(:pipeline, 3)
      filtered = Pipeline.where(id: Pipeline.first.id).page(1)

      expect(list_summary(filtered, 3, 'pipeline')).to eq '1 of 3 pipelines match'
    end

    it 'says none match when the filters left nothing' do
      create_list(:pipeline, 3)

      expect(list_summary(Pipeline.none.page(1), 3, 'pipeline')).to eq '0 of 3 pipelines match'
    end

    it 'counts one of one without pluralising' do
      create(:pipeline)

      expect(list_summary(Pipeline.page(1), 1, 'pipeline')).to eq '1 pipeline'
    end
  end

  describe '#page_summary' do
    it 'describes where a page sits in a longer list' do
      create_list(:pipeline, 25)

      expect(page_summary(Pipeline.page(2), 'pipeline')).to eq 'Showing 21–25 of 25 pipelines'
    end

    it 'describes the first page' do
      create_list(:pipeline, 25)

      expect(page_summary(Pipeline.page(1), 'pipeline')).to eq 'Showing 1–20 of 25 pipelines'
    end

    # The count it compares against is the filtered one: that is the list being paged.
    it 'counts against what the filters left, not everything' do
      create_list(:pipeline, 25)
      filtered = Pipeline.where(id: Pipeline.first(3).map(&:id)).page(1)

      expect(page_summary(filtered, 'pipeline')).to eq 'Showing 1–3 of 3 pipelines'
    end

    it 'says nothing at all for an empty list' do
      expect(page_summary(Pipeline.none.page(1), 'pipeline')).to be_nil
    end
  end

  describe '#last_edited_by' do
    it 'returns nil if resource is nil' do
      expect(last_edited_by(nil)).to be_nil
    end

    it 'returns nil if last_edited_by is nil' do
      expect(last_edited_by(Pipeline.new)).to be_nil
    end

    it 'returns a formatted string if last_edited_by has a user' do
      user = create(:user)
      pipeline = Pipeline.new(last_edited_by: user)
      expect(last_edited_by(pipeline)).to eq "Last edited by #{user.username}"
    end
  end
end
