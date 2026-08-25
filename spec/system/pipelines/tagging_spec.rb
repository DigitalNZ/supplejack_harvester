# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tagging a pipeline', :js do
  let(:user)     { create(:user) }
  let(:pipeline) { create(:pipeline, name: 'Auckland Museum') }

  before do
    sign_in user
    create(:tag, name: 'Museum')
    create(:tag, name: 'High priority')
  end

  it 'adds an existing tag from the suggestions' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    find('[data-tags-input]').click
    click_on 'Museum'
    click_on 'Save tags'

    expect(page).to have_content 'Tags updated successfully'
    expect(pipeline.tags.reload.map(&:name)).to eq ['Museum']
  end

  it 'creates a tag that does not exist yet' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    fill_in 'Search or create a tag', with: 'Audio'
    click_on '+ Create tag "Audio"'
    click_on 'Save tags'

    expect(page).to have_content 'Tags updated successfully'
    expect(pipeline.tags.reload.map(&:name)).to eq ['Audio']
  end

  it 'adds the tag being typed when Enter is pressed' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    fill_in 'Search or create a tag', with: 'Audio'
    find('[data-tags-input]').send_keys :enter
    click_on 'Save tags'

    expect(page).to have_content 'Tags updated successfully'
    expect(pipeline.tags.reload.map(&:name)).to eq ['Audio']
  end

  it 'opens the editor with the suggestions shut' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'

    expect(page).to have_field 'Search or create a tag'
    expect(page).to have_no_css '[data-tags-suggestions].show'
  end

  it 'opens the suggestions when the input is clicked' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    find('[data-tags-input]').click

    within '[data-tags-suggestions]' do
      expect(page).to have_button 'Museum'
    end
  end

  it 'narrows the suggestions to what has been typed' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    fill_in 'Search or create a tag', with: 'mus'

    within '[data-tags-suggestions]' do
      expect(page).to have_button 'Museum'
      expect(page).to have_no_button 'High priority'
    end
  end

  it 'stops offering a tag once it has been added' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    find('[data-tags-input]').click
    click_on 'Museum'
    fill_in 'Search or create a tag', with: 'Mus'

    within '[data-tags-suggestions]' do
      expect(page).to have_no_button 'Museum'
    end
  end

  # The chip is cloned from a template rendered for a tag with no colour of its own, so
  # the colour of the tag being added has to be put on it.
  it 'draws the chip for an existing tag in that tag colour' do
    Tag.find_by(name: 'Museum').update(color: :purple_rain)

    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    find('[data-tags-input]').click
    click_on 'Museum'

    expect(page).to have_css '[data-tags-chips] .tag--purple-rain', text: 'Museum'
  end

  it 'draws the chip for a tag being created in the grey a new tag starts as' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    fill_in 'Search or create a tag', with: 'Audio'
    click_on '+ Create tag "Audio"'

    expect(page).to have_css '[data-tags-chips] .tag--pompeii-ash', text: 'Audio'
  end

  it 'takes a tag off the pipeline' do
    pipeline.tags = [Tag.find_by(name: 'Museum'), Tag.find_by(name: 'High priority')]

    visit pipeline_path(pipeline)

    find('[data-tags-edit]').click
    click_on 'Remove Museum'
    click_on 'Save tags'

    expect(page).to have_content 'Tags updated successfully'
    expect(pipeline.tags.reload.map(&:name)).to eq ['High priority']
  end

  it 'leaves the pipeline alone when the editing is cancelled' do
    pipeline.tags = [Tag.find_by(name: 'Museum')]

    visit pipeline_path(pipeline)

    find('[data-tags-edit]').click
    click_on 'Remove Museum'
    click_on 'Cancel'

    expect(pipeline.tags.reload.map(&:name)).to eq ['Museum']
    expect(page).to have_css '[data-tags-edit]', visible: :visible
  end

  it 'reports a name it cannot save' do
    visit pipeline_path(pipeline)

    click_on '+ Add tags'
    fill_in 'Search or create a tag', with: '!!!'
    find('[data-tags-input]').send_keys :enter
    click_on 'Save tags'

    expect(page).to have_content I18n.t('tag.validations.name_format')
    expect(pipeline.tags.reload).to be_empty
  end
end
