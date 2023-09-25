# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestJob do
  let(:destination)        { create(:destination) }
  let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
  let(:pipeline_job)       { create(:pipeline_job, pipeline:, destination:) }
  let(:harvest_definition) { create(:harvest_definition, pipeline:) }
  let(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(harvest_job.name).to eq "#{harvest_job.harvest_definition.name}__job-#{harvest_job.id}"
    end
  end

  describe '#validations' do
    subject                  { create(:harvest_job, harvest_definition:, pipeline_job:) }

    let(:pipeline)           { create(:pipeline, name: 'NLNZCat') }
    let(:harvest_definition) { create(:harvest_definition, pipeline:) }

    it { is_expected.to validate_uniqueness_of(:key).case_insensitive.with_message('has already been taken') }
  end
end
