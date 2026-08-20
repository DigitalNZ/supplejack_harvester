# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Filtering by tag', :js do
  let(:user) { create(:user) }

  let(:museum)   { create(:tag, name: 'Museum') }
  let(:priority) { create(:tag, name: 'High priority') }

  before do
    sign_in user
    create(:pipeline, name: 'Auckland Museum', last_edited_by: user).tags = [museum, priority]
    create(:pipeline, name: 'Te Papa', last_edited_by: user).tags = [museum]
    create(:pipeline, name: 'AnyQuestions', last_edited_by: user)
  end

  it 'filters the pipelines to one tag' do
    visit pipelines_path

    click_on 'Filter by tag'
    check 'Museum'
    click_on 'Apply'

    expect(page).to have_content 'Auckland Museum'
    expect(page).to have_content 'Te Papa'
    expect(page).to have_no_content 'AnyQuestions'
  end

  it 'narrows rather than widens as tags are added' do
    visit pipelines_path

    click_on 'Filter by tag'
    check 'Museum'
    check 'High priority'
    click_on 'Apply'

    expect(page).to have_content 'Auckland Museum'
    expect(page).to have_no_content 'Te Papa'
  end

  # The other filters on the page submit with it, so the tags are one part of the query
  # rather than the whole of it.
  it 'puts the tags in the URL' do
    visit pipelines_path

    click_on 'Filter by tag'
    check 'Museum'
    click_on 'Apply'

    expect(page).to have_current_path(/tags%5B%5D=museum/)
  end

  it 'drops one tag from the filter by its chip' do
    visit pipelines_path(tags: %w[museum high-priority])

    click_on 'Stop filtering by High priority'

    expect(page).to have_current_path pipelines_path(tags: ['museum'])
    expect(page).to have_content 'Te Papa'
  end

  it 'clears the filter' do
    visit pipelines_path(tags: ['museum'])

    within '.tag-filter' do
      click_on 'Filter by tag (1)'
      click_on 'Clear'
    end

    expect(page).to have_current_path pipelines_path
    expect(page).to have_content 'AnyQuestions'
  end

  it 'keeps a search when the tags change' do
    visit pipelines_path(search: 'Museum')

    click_on 'Filter by tag'
    check 'High priority'
    click_on 'Apply'

    expect(page).to have_content 'Auckland Museum'
    expect(page).to have_field 'search', with: 'Museum'
  end

  it 'says so when nothing carries all of the tags' do
    visit pipelines_path(tags: %w[museum high-priority], search: 'Te Papa')

    expect(page).to have_content 'No pipelines carry all of those tags'

    click_on 'Clear the tag filter'

    expect(page).to have_content 'Te Papa'
  end
end
