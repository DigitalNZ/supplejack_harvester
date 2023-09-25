# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Login' do
  it 'fails with unknown user' do
    # When I enter a username and password that does not exist
    visit root_path
    fill_in 'Email', with: 'someone@example.com'
    fill_in 'Password', with: 'letmein'
    click_button 'Log in'

    # Then I expect to see an error message
    expect(page).to have_css('.alert', text: 'Invalid Email or password.')
  end

  context 'when enforce_two_factor is false' do
    context 'when two factor is not setup' do
      it 'user can login without 2FA' do
        user = create(:user)
        visit root_path

        fill_in 'Email', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Log in'

        expect(page).to have_css('.header__title', text: 'Pipelines')
      end
    end

    context 'when two factor is already setup' do
      it 'cannot go to another page after login with 2FA on' do
        user = create(:user, :two_factor_setup)
        visit root_path

        fill_in 'Email', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Log in'

        expect(page).to have_css('.header__title', text: 'Two Factor Authentication')

        # make sure you get redirected to the 2FA page
        visit root_path
        expect(page).to have_css('.header__title', text: 'Log in')
      end

      it 'cannot log in with an invalid OTP' do
        user = create(:user, :two_factor_setup)
        visit root_path

        fill_in 'Email', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Log in'

        expect(page).to have_css('.header__title', text: 'Two Factor Authentication')

        fill_in '2FA Code', with: 'invalid-otp'
        click_button 'Log in'

        expect(page).to have_content('Invalid two factor code')
      end
    end
  end

  context 'when enforce_two_factor is true' do
    context 'when two factor is not setup' do
      it 'user must set up 2FA before accessing pages and cannot access other pages' do
        user = create(:user, :enforce_two_factor)
        visit root_path

        fill_in 'Email', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Log in'

        expect(page).to have_css('.header__title', text: 'Setting up 2FA')

        visit root_path
        expect(page).to have_css('.header__title', text: 'Setting up 2FA')
      end
    end

    context 'when two factor is already setup' do
      it 'cannot go to another page after email and password login' do
        user = create(:user, :enforce_two_factor, :two_factor_setup)
        visit root_path

        fill_in 'Email', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Log in'

        expect(page).to have_css('.header__title', text: 'Two Factor Authentication')

        # make sure you get redirected to the 2FA page
        visit root_path
        expect(page).to have_css('.header__title', text: 'Log in')
      end

      it 'can log in with a valid OTP' do
        user = create(:user, :enforce_two_factor, :two_factor_setup)
        visit root_path

        fill_in 'Email', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Log in'

        expect(page).to have_css('.header__title', text: 'Two Factor Authentication')

        fill_in '2FA Code', with: user.current_otp
        click_button 'Log in'

        expect(page).to have_content('Signed in successfully.')
        expect(page).to have_css('.header__title', text: 'Pipelines')
      end
    end
  end
end
