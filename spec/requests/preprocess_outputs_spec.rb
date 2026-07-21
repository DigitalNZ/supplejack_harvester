# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PreprocessOutputs' do
  let(:user)     { create(:user) }
  let(:pipeline) { create(:pipeline) }
  let(:preprocess_definition) do
    create(:harvest_definition, kind: 'preprocess', position: 0, pipeline:)
  end
  let(:pipeline_job) { create(:pipeline_job, pipeline:) }
  let(:output)       { PreProcess::Output.new(pipeline_job.id, preprocess_definition.position) }

  before { sign_in user }

  after { FileUtils.rm_rf(PreProcess::Output.folder(pipeline_job.id, preprocess_definition.position)) }

  describe '#index' do
    it 'lists runs that have preprocessed data' do
      output.write_page(1, [{ 'title' => 'Record A' }])

      get pipeline_harvest_definition_preprocess_outputs_path(pipeline, preprocess_definition)

      expect(response).to be_successful
      expect(response.body).to include "Job ##{pipeline_job.id}"
    end

    it 'does not list runs without preprocessed data' do
      pipeline_job

      get pipeline_harvest_definition_preprocess_outputs_path(pipeline, preprocess_definition)

      expect(response).to be_successful
      expect(response.body).not_to include "Job ##{pipeline_job.id}"
      expect(response.body).to include 'This block has no pre-processed data yet'
    end
  end

  describe '#show' do
    it 'displays the preprocessed records for a page' do
      output.write_page(1, [{ 'title' => 'Record A' }])

      get pipeline_harvest_definition_preprocess_output_path(pipeline, preprocess_definition, pipeline_job)

      expect(response).to be_successful
      expect(response.body).to include 'Record A'
    end

    it 'displays a message when the run has no preprocessed data' do
      get pipeline_harvest_definition_preprocess_output_path(pipeline, preprocess_definition, pipeline_job)

      expect(response).to be_successful
      expect(response.body).to include 'This run has no pre-processed data'
    end

    it 'raises RecordNotFound for a pipeline job belonging to another pipeline' do
      other_job = create(:pipeline_job)

      expect do
        get pipeline_harvest_definition_preprocess_output_path(pipeline, preprocess_definition, other_job)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
