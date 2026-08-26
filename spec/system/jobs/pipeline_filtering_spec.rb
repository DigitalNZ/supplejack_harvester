# frozen_string_literal: true

require 'rails_helper'

# The filters on a pipeline's jobs used to post to the global list, carrying the pipeline
# as a parameter: you filtered one pipeline's jobs and landed on every pipeline's, narrowed
# back down by an id in the query, with the columns of the wider list.
RSpec.describe "Filtering one pipeline's jobs", :js do
  let(:user)        { create(:user) }
  let(:destination) { create(:destination, name: 'Production API') }
  let(:pipeline)    { create(:pipeline, name: 'Auckland Museum') }

  before do
    sign_in user

    definition = create(:harvest_definition, pipeline:)
    job = create(:pipeline_job, pipeline:, destination:, harvest_definitions_to_run: [definition.id])
    harvest_job = create(:harvest_job, harvest_definition: definition, pipeline_job: job)
    create(:harvest_report, pipeline_job: job, harvest_job:, name: 'Auckland Museum job')
  end

  it 'stays on the pipeline when a filter changes' do
    visit pipeline_pipeline_jobs_path(pipeline)

    select 'Run by: Schedule', from: 'run_by'

    expect(page).to have_current_path(/#{Regexp.escape(pipeline_pipeline_jobs_path(pipeline))}/)
    expect(page).to have_no_current_path(%r{\A/jobs})
  end

  it "keeps the pipeline's own columns after filtering" do
    visit pipeline_pipeline_jobs_path(pipeline)

    select 'All statuses', from: 'status'

    expect(page).to have_css 'th', text: 'Destination · Run by'
    expect(page).to have_no_css 'th', text: 'Pipeline'
  end

  # Tags belong to pipelines, so filtering one pipeline's jobs by them is all of them or
  # none of them - there is nothing to narrow. The global list is where it means something.
  it 'does not offer to filter by tag' do
    pipeline.tags = [create(:tag, name: 'Museum')]

    visit pipeline_pipeline_jobs_path(pipeline)

    expect(page).to have_no_button 'Filter by tag'
    expect(page).to have_select 'status'
  end

  it 'still offers it on the list of every job' do
    pipeline.tags = [create(:tag, name: 'Museum')]

    visit jobs_path

    expect(page).to have_button 'Filter by tag'
  end
end
