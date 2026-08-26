# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'The homepage' do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'lists every part of the app, with a line on what it is' do
    visit root_path

    expect(page).to have_link 'Pipelines'
    expect(page).to have_link 'Tags'
    expect(page).to have_link 'Automation Templates'
    expect(page).to have_link 'Destinations'
    expect(page).to have_link 'Schemas'
    expect(page).to have_link 'Schedules'
    expect(page).to have_link 'Jobs'
    expect(page).to have_content 'The labels pipelines are grouped and filtered by'
  end

  it 'reaches the tags from the card, which is where the nav used to take you' do
    create(:tag, name: 'Musuem')

    visit root_path
    within('.card', text: 'The labels pipelines are grouped') { click_on 'Tags' }

    expect(page).to have_css 'h1', text: 'Tags'
    expect(page).to have_content 'Musuem'
  end

  it 'reaches the pipelines from the card' do
    visit root_path
    within('.card', text: 'Each source that is harvested') { click_on 'Pipelines' }

    expect(page).to have_css '.header__title', text: 'Pipelines'
  end
end
