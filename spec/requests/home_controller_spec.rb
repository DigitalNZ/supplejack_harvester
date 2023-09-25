# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home' do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe '#index' do
    it 'redirects to the pipelines page' do
      get root_path
      expect(response).to redirect_to pipelines_path
    end
  end
end
