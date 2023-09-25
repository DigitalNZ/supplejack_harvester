# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TwoFactorSetups' do
  describe '#create' do
    let(:user) { create(:user) }

    before do
      sign_in user

      # gets the otp_secret set
      get two_factor_setups_path
    end

    it 'sets a flash message if successful' do
      post two_factor_setups_path, params: { user: { otp_attempt: user.current_otp } }

      expect(response).to redirect_to root_path
      follow_redirect!
      follow_redirect! # redirection to content_sources
      expect(response.body).to include 'Two Factor Authentication successfully set up'
    end

    it 'sets a error message if not successful and renders show again' do
      post two_factor_setups_path, params: { user: { otp_attempt: '123' } }

      expect(response.body).to include 'Two Factor Authentication failed. Please try and input your code again.'
    end
  end

  describe '#destroy' do
    context 'when enforce_two_factor is true' do
      it 'renders an error message' do
        user = create(:user, :enforce_two_factor, :two_factor_setup)
        sign_in user
        user.update(enforce_two_factor: true)
        delete two_factor_setups_path

        expect(response).to redirect_to root_path
        follow_redirect!
        follow_redirect!
        expect(response.body).to include '2FA was made mandatory for you by admins'
        user.reload
        expect(user.otp_required_for_login).to be true
      end
    end

    it 'sets an error message' do
      user = create(:user, :two_factor_setup)
      sign_in user
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return user
      allow(user).to receive(:update).and_return false

      delete two_factor_setups_path
      expect(response).to redirect_to edit_profile_path
      follow_redirect!
      expect(response.body).to include 'There was a problem disabling 2FA'
    end

    it 'sets an successful message' do
      sign_in create(:user, :two_factor_setup)
      delete two_factor_setups_path

      expect(response).to redirect_to edit_profile_path
      follow_redirect!
      expect(response.body).to include 'Two Factor Authentication successfully disabled'
    end
  end
end
