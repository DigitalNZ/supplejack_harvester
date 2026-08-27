# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  # The three slots of the page header. A page states what goes in them; what they look
  # like is written once, in the helpers and the layout.
  describe '#page_heading' do
    it 'puts the title in the heading slot as the only h1 on the page' do
      helper.page_heading 'Pipelines'

      expect(helper.content_for(:heading)).to eq '<h1>Pipelines</h1>'
    end

    it 'sets a subtitle under the title when the page gives one' do
      helper.page_heading 'Jobs', 'Global view of pipeline jobs'

      expect(helper.content_for(:heading))
        .to eq '<h1>Jobs</h1><p class="text-muted mb-0">Global view of pipeline jobs</p>'
    end

    it 'escapes what it is given rather than trusting it as markup' do
      helper.page_heading '<script>', '<script>'

      expect(helper.content_for(:heading)).not_to include '<script>'
    end

    it 'leaves out the subtitle line when the page has nothing to say under the title' do
      helper.page_heading 'Pipelines'

      expect(helper.content_for(:heading)).not_to include 'text-muted'
    end

    it 'takes a block for a subtitle that is more than words' do
      helper.page_heading('Job 1') { '<p>Started</p>'.html_safe }

      expect(helper.content_for(:heading)).to eq '<h1>Job 1</h1><p>Started</p>'
    end

    it 'builds the whole heading from the block when the title is not plain text' do
      helper.page_heading { '<h1>Edited in place</h1>'.html_safe }

      expect(helper.content_for(:heading)).to eq '<h1>Edited in place</h1>'
    end
  end

  describe '#page_actions' do
    it 'puts what it is given in the actions slot' do
      helper.page_actions { '<button>Delete</button>'.html_safe }

      expect(helper.content_for(:actions)).to eq '<button>Delete</button>'
    end
  end

  describe '#page_tabs' do
    it 'puts what it is given in the tab slot' do
      helper.page_tabs { '<ul class="nav nav-tabs"></ul>'.html_safe }

      expect(helper.content_for(:nav_tabs)).to eq '<ul class="nav nav-tabs"></ul>'
    end
  end

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
