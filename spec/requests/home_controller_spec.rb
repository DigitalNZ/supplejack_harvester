# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home' do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe '#index' do
    # It used to pass straight on to the pipelines list rather than render anything.
    it 'renders a page of its own' do
      get root_path

      expect(response).to have_http_status :ok
    end

    it 'says what each part of the app it links to is for' do
      get root_path

      expect(response.body).to include 'Each source that is harvested'
      expect(response.body).to include 'The labels pipelines are grouped and filtered by'
    end
  end
end
