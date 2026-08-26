# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Statuses' do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /statuses' do
    it 'renders' do
      get statuses_path

      expect(response).to have_http_status :ok
    end

    # Asserted against the same constants the page reads, so a status added to either set
    # fails here until the page can draw it.
    it 'draws every status a job or an automation can be in' do
      get statuses_path

      (Job::STATUSES | StatusManagement::STATUS_PRIORITY.keys).each do |status|
        expect(response.body).to include status.humanize
      end
    end

    it 'draws each one with its icon rather than as the word alone' do
      get statuses_path

      expect(response.body).to include 'bi-check-circle-fill', 'bi-exclamation-triangle-fill',
                                       'bi-hourglass-split', 'bi-play-circle-fill',
                                       'bi-x-circle-fill', 'bi-dash-circle'
    end

    it 'names the column each status is stored in' do
      get statuses_path

      expect(response.body).to include '<code class="small text-muted">not_started</code>'
    end
  end
end
