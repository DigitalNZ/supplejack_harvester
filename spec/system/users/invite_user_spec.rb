# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invite user' do
  let(:admin) { create(:user, role: :admin) }

  before do
    sign_in admin
  end

  it 'admin can invite a user' do
    visit root_path

    click_link admin.username # nav button
    click_link 'Manage users'

    click_button 'Invite user'
    fill_in 'Username', with: 'Invited user'
    fill_in 'Email', with: 'invite@user.com'

    click_button 'Invite'

    expect(page).to have_content 'An invitation email has been sent to invite@user.com'
  end
end
