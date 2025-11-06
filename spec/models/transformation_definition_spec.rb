# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransformationDefinition do
  let(:pipeline)              { create(:pipeline, :figshare, name: 'National Library of New Zealand') }
  let(:extraction_definition) { pipeline.harvest.extraction_definition }
  let(:extraction_job)        { create(:extraction_job, extraction_definition:) }
  let(:request)                 { create(:request, :figshare_initial_request, extraction_definition:) }
  let(:subject) do
    create(:transformation_definition, pipeline:, extraction_job:, record_selector: '$..items')
  end

  let!(:field_one) do
    create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition: subject)
  end
  let!(:field_two) do
    create(:field, name: 'source', block: "JsonPath.new('source').on(record).first", transformation_definition: subject)
  end

  before do
    # that's to test the display of results
    stub_figshare_harvest_requests(request)
    ExtractionWorker.new.perform(extraction_job.id)
  end

  describe '#attributes' do
    it 'has a record selector' do
      expect(subject.record_selector).to eq '$..items'
    end

    it 'belongs to a pipeline' do
      expect(subject.pipeline).to eq pipeline
    end

    it 'has a job' do
      expect(subject.extraction_job).to eq extraction_job
    end
  end

  describe '#records' do
    it 'returns the records from the job documents' do
      expect(subject.records.first).to have_key 'article_id'
    end
  end

  describe 'kinds' do
    let(:harvest_transformation_definition) { create(:transformation_definition, kind: :harvest) }
    let(:enrichment_transformation_definition) { create(:transformation_definition, kind: :enrichment) }

    it 'can be for a harvest' do
      expect(harvest_transformation_definition.harvest?).to be true
    end

    it 'can be for an enrichment' do
      expect(enrichment_transformation_definition.enrichment?).to be true
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(subject.name).to eq "#{subject.id}_harvest-transformation"
    end
    
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.with_message('has already been taken') }
  end

  describe '#shared?' do
    let!(:harvest_definition_one) { create(:harvest_definition, transformation_definition: shared, pipeline:) }
    let!(:harvest_definition_two) { create(:harvest_definition, transformation_definition: shared, pipeline:) }
    let!(:harvest_definition_three) { create(:harvest_definition, transformation_definition: standalone, pipeline:) }

    let(:shared)     { create(:transformation_definition, pipeline:) }
    let(:standalone) { create(:transformation_definition, pipeline:) }

    it 'returns true if the transformation definition is used in more than one harvest definition' do
      expect(shared.shared?).to be true
    end

    it 'returns false if the transformation definition is used in only one harvest definition' do
      expect(standalone.shared?).to be false
    end
  end

  describe '#clone' do
    let(:pipeline_two)               { create(:pipeline) }

    let!(:harvest_definition)        { create(:harvest_definition, transformation_definition: subject, pipeline:) }
    let!(:harvest_definition_two)    { create(:harvest_definition, transformation_definition: subject, pipeline: pipeline_two) }

    it 'creates a new TransformationDefinition with the same details' do
      cloned_transformation_definition = subject.clone(pipeline_two, 'clone')

      cloned_transformation_definition.save
      expect(cloned_transformation_definition.fields.count).to eq subject.fields.count

      cloned_transformation_definition.fields.zip(subject.fields) do |cloned_field, field|
        expect(cloned_field.name).to eq field.name
        expect(cloned_field.block).to eq field.block
        expect(cloned_field.kind).to eq field.kind
      end
    end

    it 'assigns the new Transformation Definition to the provided Pipeline' do
      expect(harvest_definition_two.transformation_definition).to eq subject

      cloned_transformation_definition = subject.clone(pipeline_two, 'clone')

      cloned_transformation_definition.save
      expect(cloned_transformation_definition.pipeline).to eq pipeline_two
    end

    it 'assigns the provided name to the ExtractionDefinition clone' do
      cloned_transformation_definition = subject.clone(pipeline_two, 'clone')

      cloned_transformation_definition.save
      expect(cloned_transformation_definition.name).to eq 'clone'
    end
  end
end
