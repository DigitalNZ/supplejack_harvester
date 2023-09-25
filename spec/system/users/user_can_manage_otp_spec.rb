# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User can manage OTP' do
  context 'when enforce_two_factor is false' do
    it 'user can enable and disable it', js: true do
      user = create(:user)
      sign_in user

      visit edit_profile_path

      click_link 'Set up 2FA'

      user.reload
      fill_in '2FA Code', with: user.current_otp
      click_button 'Confirm'

      expect(page).to have_content('Two Factor Authentication successfully set up')

      visit edit_profile_path

      click_button 'Disable 2FA'
      within('#disable-2fa-modal') do
        click_button 'Disable' # confirmation modal
      end
      expect(page).to have_content('Two Factor Authentication successfully disabled')
    end
  end

  context 'when enforce_two_factor is true' do
    it 'user cannot disable it' do
      user = create(:user, :enforce_two_factor, :two_factor_setup)
      sign_in user

      visit edit_profile_path

      expect(page).not_to have_link('Disable 2FA')
    end
  end
end
