# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transformation::Execution do
  let(:pipeline)                  { create(:pipeline, :figshare) }
  let(:extraction_definition)     { pipeline.harvest.extraction_definition }
  let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition) { create(:transformation_definition, extraction_job:) }

  let(:record) do
    {
      'record_id' => 1123,
      'title' => 'The title of the record',
      'description' => 'The description of the record'
    }
  end
  let(:field) { create(:field, transformation_definition:) }
  let(:field_with_error) { create(:field, transformation_definition:, block: 'result.title') }

  describe '#call' do
    it 'returns the result of applying the field to the record' do
      transformation = described_class.new([record], [field]).call.first.transformed_record

      expect(transformation['title']).to eq 'The title of the record'
    end

    it 'updates the error message on the field if an error has occured applying the field' do
      errors = described_class.new([record], [field_with_error]).call.first.errors

      expect(errors[field_with_error.id][:title]).to eq NameError
      expect(errors[field_with_error.id][:description]).to include "undefined local variable or method `result'"
    end

    it 'records field errors against the provided harvest job' do
      field_error = create(:field, transformation_definition:, block: 'result.title')
      harvest_definition = create(:harvest_definition, pipeline:, extraction_definition:, transformation_definition:)
      previous_harvest_job = create(:harvest_job, harvest_definition:)
      current_harvest_job = create(:harvest_job, harvest_definition:)

      described_class.new([record], [field_error], harvest_job: current_harvest_job).call

      recorded_error = JobError.where(origin: 'Transformation::FieldExecution').order(created_at: :desc).first
      expect(recorded_error).to be_present
      expect(recorded_error.job_id).to eq(current_harvest_job.id)
      expect(recorded_error.job_id).not_to eq(previous_harvest_job.id)
      expect(recorded_error.job_type).to eq('TransformationJob')
    end
  end
end
