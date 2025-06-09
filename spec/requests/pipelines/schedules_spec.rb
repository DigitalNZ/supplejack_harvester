# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pipelines::SchedulesController, type: :request do
  let(:user) { create(:user) }
  let(:pipeline) { create(:pipeline) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a successful response' do
      get pipeline_schedules_path(pipeline_id: pipeline.id)
      expect(response).to be_successful
    end
  end
end