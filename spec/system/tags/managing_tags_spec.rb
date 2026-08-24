# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Managing tags', :js do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'lists the tags and what carries them' do
    create(:pipeline, name: 'Auckland Museum', last_edited_by: user).tags = [create(:tag, name: 'Museum')]
    create(:tag, name: 'Musuem')

    visit tags_path

    expect(page).to have_content 'Museum'
    expect(page).to have_content 'Musuem'
    expect(page).to have_link '1'
    expect(page).to have_content 'None'
  end

  it 'renames a mis-spelt tag' do
    tag = create(:tag, name: 'Musuem')
    create(:pipeline, name: 'Auckland Museum', last_edited_by: user).tags = [tag]

    visit tags_path

    click_on 'Edit'
    fill_in 'Name', with: 'Museum'
    click_on 'Update'

    expect(page).to have_content 'Tag updated successfully'
    expect(tag.reload.name).to eq 'Museum'
  end

  it 'reports a rename it cannot save' do
    create(:tag, name: 'Museum')
    tag = create(:tag, name: 'Musuem')

    visit edit_tag_path(tag)

    fill_in 'Name', with: 'Museum'
    click_on 'Update'

    expect(page).to have_content 'has already been taken'
    expect(tag.reload.name).to eq 'Musuem'
  end

  it 'deletes a tag once the deletion is confirmed' do
    tag = create(:tag, name: 'Musuem')
    create(:pipeline, name: 'Auckland Museum', last_edited_by: user).tags = [tag]

    visit tags_path

    click_on 'Delete'

    within '.modal.show' do
      expect(page).to have_content 'It will be taken off the 1 pipeline carrying it.'

      click_on 'Delete'
    end

    expect(page).to have_content 'Musuem was deleted'
    expect(page).to have_content 'There are currently no tags'
    expect(Tag.count).to eq 0
  end

  it 'leaves the tag alone when the deletion is not confirmed' do
    create(:tag, name: 'Musuem')

    visit tags_path

    click_on 'Delete'

    # The header's × carries the same accessible name, so this is the footer's button.
    within '.modal.show .modal-footer' do
      click_on 'Close'
    end

    expect(page).to have_content 'Musuem'
    expect(Tag.count).to eq 1
  end

  it 'stops offering a deleted tag as a suggestion' do
    pipeline = create(:pipeline, name: 'Auckland Museum', last_edited_by: user)
    create(:tag, name: 'Musuem')

    visit tags_path
    click_on 'Delete'
    within('.modal.show') { click_on 'Delete' }

    # Waiting for the deletion to land before moving on: the click only submits the form,
    # and navigating away first leaves its response to arrive over the next page.
    expect(page).to have_content 'Musuem was deleted'

    visit pipeline_path(pipeline)
    click_on '+ Add tags'
    fill_in 'Search or create a tag', with: 'Mus'

    within '[data-tags-suggestions]' do
      expect(page).to have_no_button 'Musuem'
    end
  end
end
