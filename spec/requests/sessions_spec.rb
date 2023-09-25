# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions' do
  let(:user) { create(:user) }

  describe 'DELETE /sign_out' do
    it 'redirects to sign in path and sets a message' do
      sign_in user
      delete destroy_user_session_path

      expect(response).to redirect_to new_user_session_path
      follow_redirect!
      expect(response.body).to include 'Signed out successfully.'

      get root_path
      expect(response).to redirect_to new_user_session_path
    end
  end
end
