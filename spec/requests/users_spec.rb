# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users' do
  let(:admin) { create(:user, role: :admin) }
  let(:user) { create(:user) }

  describe 'GET /index' do
    it 'displays a list of users if user is admin' do
      sign_in admin
      get users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include admin.username
    end

    it 'redirects if not admin' do
      sign_in user
      get users_path

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to root_path
    end
  end

  describe 'GET /show' do
    it 'displays user details if admin' do
      sign_in admin
      get user_path(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include admin.username
      expect(response.body).to include admin.role
    end

    it 'redirects if not admin' do
      sign_in user
      get user_path(admin)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to root_path
    end
  end

  describe 'GET /edit' do
    it 'is successful if admin' do
      sign_in admin
      get edit_user_path(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include admin.username
    end

    it 'redirects if not admin' do
      sign_in user
      get edit_user_path(user)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to root_path
    end
  end

  describe 'PATCH /update' do
    it 'is successful if admin' do
      sign_in admin
      patch user_path(user, user: { username: 'New username' })

      expect(response).to redirect_to user_path(user)
      follow_redirect!
      expect(response.body).to include 'New username'
      expect(response.body).to include 'User updated successfully'
    end

    it 'sets an error message on failure' do
      sign_in admin
      patch user_path(user), params: {
        user: { username: '1' }
      }
      expect(response.body).to include 'There was an issue updating the user'
    end

    it 'redirects if not admin' do
      sign_in user
      patch user_path(user, user: { username: 'New username' })

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to root_path
    end
  end

  describe 'DELETE /destroy' do
    it 'is successful if admin' do
      sign_in admin
      delete user_path(user)

      expect(response).to redirect_to users_path
      follow_redirect!
      expect(response.body).to include 'User removed successfully'
    end

    it 'sets an error message if not successful' do
      sign_in admin
      fake_user = instance_double(User)
      allow(User).to receive(:find).and_return fake_user
      allow(fake_user).to receive(:destroy).and_return false
      delete user_path(user)

      expect(response).to redirect_to users_path
      follow_redirect!
      expect(response.body).to include 'There was an issue deleting the user'
    end

    it 'redirects if not admin' do
      sign_in user
      delete user_path(user)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to root_path
    end
  end
end
