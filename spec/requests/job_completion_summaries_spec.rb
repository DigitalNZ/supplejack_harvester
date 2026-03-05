# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JobCompletionSummaries' do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET /job_completion_summaries' do
    it 'renders the summary row without querying the removed job_completions table' do
      extraction_job = create(:extraction_job,
                              stop_condition_type: 'system',
                              stop_condition_name: 'Set number reached',
                              stop_condition_content: '')

      summary = create(:job_completion_summary,
                       job_id: extraction_job.id,
                       process_type: :extraction,
                       job_type: 'ExtractionJob')

      create(:job_error,
             job_completion_summary: summary,
             job_id: extraction_job.id,
             job_type: 'ExtractionJob')

      get job_completion_summaries_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Completions')
      expect(response.body).to include('Errors')
    end
  end
end
