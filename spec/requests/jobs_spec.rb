require 'rails_helper'

RSpec.describe "Jobs", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /index" do
    it 'displays a list of all jobs' do
      get jobs_path

      expect(response).to have_http_status :ok
    end
  end
end
