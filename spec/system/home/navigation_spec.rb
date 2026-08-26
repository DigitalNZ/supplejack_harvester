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
    expect(page).to have_link 'Job Completion Summary'
    expect(page).to have_content 'The labels pipelines are grouped and filtered by'
  end

  it 'reaches the job completion summary from the card' do
    visit root_path
    within('.card', text: 'hit a stop condition') { click_on 'Job Completion Summary' }

    expect(page).to have_css 'h1', text: 'Job Completion Summary'
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

RSpec.describe 'The nav' do
  let(:user) { create(:user) }

  before { sign_in user }

  # Destinations and Schemas are reached from their homepage cards now, the way Tags
  # already was.
  it 'opens with Home, and leaves the destinations and the schemas to the cards' do
    visit root_path

    within('nav') do
      expect(all('.nav-link').map(&:text).first(2)).to eq ['Home', 'Pipelines']
      expect(page).to have_no_link 'Destinations'
      expect(page).to have_no_link 'Schemas'
    end
  end

  # An automation has no nav item of its own; it belongs to the template it was run from.
  it 'lights Automation Templates on an automation of its own' do
    visit automation_path(create(:automation))

    within('nav') { expect(find('.nav-link.active').text).to eq 'Automation Templates' }
  end

  it 'lights Automation Templates on a template' do
    visit automation_template_path(create(:automation_template))

    within('nav') { expect(find('.nav-link.active').text).to eq 'Automation Templates' }
  end
end
