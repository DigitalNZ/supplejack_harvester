# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Filtering jobs by tag', :js do
  let(:user)        { create(:user) }
  let(:destination) { create(:destination) }
  let(:museum)      { create(:tag, name: 'Museum') }
  let(:priority)    { create(:tag, name: 'High priority') }

  before do
    sign_in user

    both = create(:pipeline, name: 'Auckland Museum')
    both.tags = [museum, priority]
    museum_only = create(:pipeline, name: 'Te Papa')
    museum_only.tags = [museum]

    [both, museum_only, create(:pipeline, name: 'AnyQuestions')].each do |pipeline|
      definition = create(:harvest_definition, pipeline:)
      job = create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [definition.id])
      harvest_job = create(:harvest_job, harvest_definition: definition, pipeline_job: job)
      create(:harvest_report, pipeline_job: job, harvest_job:, name: "#{pipeline.name} job")
    end
  end

  it 'filters the jobs to the pipelines carrying the tag' do
    visit jobs_path

    click_on 'Filter by tag'
    check 'Museum'
    click_on 'Apply'

    expect(page).to have_link 'Auckland Museum'
    expect(page).to have_link 'Te Papa'
    expect(page).to have_no_link 'AnyQuestions'
  end

  it 'narrows rather than widens as tags are added' do
    visit jobs_path(tags: %w[museum high-priority])

    expect(page).to have_link 'Auckland Museum'
    expect(page).to have_no_link 'Te Papa'
  end

  it 'keeps the tag filter when another filter changes' do
    visit jobs_path(tags: ['museum'])

    select 'Completed', from: 'status'

    expect(page).to have_current_path(/tags%5B%5D=museum/)
    expect(page).to have_content 'No jobs belong to a pipeline carrying all of those tags'
  end
end
