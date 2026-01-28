# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelineJob do
  let(:destination)        { create(:destination) }

  describe 'associations' do
    it { is_expected.to have_many(:harvest_reports) }
  end

  describe '#validations' do
    subject                  { create(:pipeline_job, pipeline:, destination:) }

    let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
    let(:harvest_definition) { create(:harvest_definition, pipeline:) }

    it 'requires pages if the page_type is set_number' do
      job = build(:pipeline_job, pipeline:, destination:, page_type: 'set_number')

      expect(job).not_to be_valid
      expect(job.errors['pages']).to include "can't be blank"
    end

    it 'does not requires pages if the page_type is all_available_pages' do
      job = build(:pipeline_job, pipeline:, destination:, page_type: 'all_available_pages')

      expect(job).to be_valid
    end
  end
end
