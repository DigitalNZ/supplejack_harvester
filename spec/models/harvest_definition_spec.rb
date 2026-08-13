# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HarvestDefinition do
  subject do
    create(
      :harvest_definition,
      pipeline:,
      source_id: 'test',
      extraction_definition:,
      transformation_definition:
    )
  end

  let(:pipeline)                    { create(:pipeline, name: 'National Library of New Zealand') }
  let(:harvest_definition)          do
    create(:harvest_definition, pipeline:, extraction_definition:, transformation_definition:)
  end
  let(:extraction_definition)       { create(:extraction_definition) }
  let(:extraction_job)              { create(:extraction_job, extraction_definition:) }
  let(:transformation_definition)   { create(:transformation_definition, extraction_job:) }

  describe '#attributes' do
    it 'belongs to a pipeline' do
      expect(subject.pipeline).to eq pipeline
    end

    it 'has an extraction definition' do
      expect(subject.extraction_definition).to eq extraction_definition
    end

    it 'has a transformation definition' do
      expect(subject.transformation_definition).to eq transformation_definition
    end
  end

  describe '#name' do
    it 'automatically generates a sensible name' do
      expect(subject.name).to eq "#{subject.id}_harvest"
    end
  end

  describe '#kinds' do
    it 'can be for a harvest' do
      subject.update(kind: :harvest)
      subject.reload
      expect(subject.harvest?).to be true
    end

    it 'can be for an enrichment' do
      subject.update(kind: :enrichment)
      subject.reload
      expect(subject.enrichment?).to be true
    end
  end

  describe 'kind enum' do
    it 'supports a preprocess kind' do
      definition = create(:harvest_definition, kind: :preprocess)
      expect(definition.preprocess?).to be true
    end
  end

  describe '#load_kind' do
    it 'is the kind of the load definition when the block has one' do
      load_definition = create(:load_definition, pipeline:, kind: 'secondary_fragment')

      expect(create(:harvest_definition, pipeline:, load_definition:).load_kind).to eq 'secondary_fragment'
    end

    context 'when the block has no load definition' do
      it 'derives writing the primary fragment from a harvest block' do
        expect(create(:harvest_definition, pipeline:, kind: :harvest).load_kind).to eq 'primary_fragment'
      end

      it 'derives an enrichment from an enrichment block' do
        expect(create(:harvest_definition, pipeline:, kind: :enrichment).load_kind).to eq 'enrichment'
      end

      it 'derives writing to disk from a preprocess block' do
        expect(create(:harvest_definition, pipeline:, kind: :preprocess).load_kind).to eq 'file'
      end
    end
  end

  describe '#ready_to_run?' do
    it 'returns false if it has no extraction definition' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline:, extraction_definition: nil)

      expect(harvest_definition.ready_to_run?).to be false
    end

    it 'returns false if it has an extraction_definition but no transformation definition' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline:, transformation_definition: nil)

      expect(harvest_definition.ready_to_run?).to be false
    end

    it 'returns false if it has an extraction definition, transformation definition but no fields' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline:)

      expect(harvest_definition.ready_to_run?).to be false
    end

    it 'returns true if it has an extraction_definition and a transformation_definition with fields' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline:)
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                     transformation_definition: pipeline.harvest.transformation_definition)

      expect(harvest_definition.ready_to_run?).to be true
    end
  end

  describe '#configuration_problems' do
    let(:pipeline) { create(:pipeline) }
    let(:block) do
      definition = create(:harvest_definition, pipeline:)
      create(:field, name: 'internal_identifier', block: "JsonPath.new('id').on(record).first",
                     transformation_definition: definition.transformation_definition)
      definition
    end

    it 'says nothing about a coherently configured block' do
      expect(block.configuration_problems).to be_empty
    end

    it 'lists what is missing' do
      definition = create(:harvest_definition, pipeline:, extraction_definition: nil)

      expect(definition.configuration_problems).to contain_exactly(
        'it has no extraction definition', 'its transformation has no fields'
      )
    end

    context 'when the block writes a secondary fragment' do
      before { block.update(load_definition: create(:load_definition, pipeline:, kind: 'secondary_fragment', priority: -1)) }

      it 'accepts a transformation that sets internal_identifier' do
        expect(block.configuration_problems).to be_empty
      end

      it 'requires internal_identifier, which is how the record is found' do
        block.transformation_definition.fields.find_by(name: 'internal_identifier').destroy
        create(:field, name: 'tag', block: '"CEISMIC"', transformation_definition: block.transformation_definition)

        expect(block.reload.configuration_problems).to include(
          'it writes a secondary fragment, so its transformation has to set internal_identifier'
        )
      end

      it 'rejects delete_if rules it cannot honour' do
        create(:field, kind: 'delete_if', name: 'gone', block: 'false',
                       transformation_definition: block.transformation_definition)

        expect(block.reload.configuration_problems.join).to include 'delete_if rules cannot be'
      end
    end

    it 'does not second-guess an enrichment against its extraction' do
      # ExtractionWorker#iterate_previous? hands an api_record to more blocks than just those
      # with an enrichment extraction, so requiring one here would ground working pipelines.
      block.update(load_definition: create(:load_definition, pipeline:, kind: 'enrichment', priority: -1))

      expect(block.configuration_problems).to be_empty
    end

    context 'when the block writes a file' do
      let(:load_definition) { create(:load_definition, pipeline:, kind: 'file') }

      it 'is only allowed on a pre-processing block' do
        block.update(load_definition:)

        expect(block.configuration_problems).to include(
          'only a pre-processing block can write a file for the next block to read'
        )
      end

      it 'is what a pre-processing block has to do' do
        block.update(kind: :preprocess, load_definition: create(:load_definition, pipeline:))

        expect(block.configuration_problems).to include(
          'it is a pre-processing block, so it has to write a file for the next block to read'
        )
      end
    end
  end

  describe '#clone' do
    let(:pipeline)                  { create(:pipeline) }
    let(:pipeline_two)              { create(:pipeline) }

    let(:extraction_definition)     { create(:extraction_definition) }
    let!(:request_one)              { create(:request, :figshare_initial_request, extraction_definition:) }
    let!(:request_two)              { create(:request, :figshare_main_request, extraction_definition:) }

    let(:extraction_job)            { create(:extraction_job, extraction_definition:) }
    let(:request)                   { create(:request, :figshare_initial_request, extraction_definition:) }
    let(:transformation_definition) do
      create(:transformation_definition, pipeline:, extraction_job:, record_selector: '$..items')
    end
  
    let!(:field_one) do
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first", transformation_definition:)
    end
    let!(:field_two) do
      create(:field, name: 'source', block: "JsonPath.new('source').on(record).first", transformation_definition:)
    end

    let!(:harvest_definition)    { create(:harvest_definition, extraction_definition:, transformation_definition:, pipeline:, priority: -1) }

    it 'creates a new HarvestDefinition with the same attributes' do
      cloned_harvest_definition = harvest_definition.clone(pipeline_two)

      cloned_harvest_definition.save

      expect(cloned_harvest_definition.kind).to eq harvest_definition.kind
      expect(cloned_harvest_definition.priority).to eq harvest_definition.priority

      expect(cloned_harvest_definition.extraction_definition).to eq harvest_definition.extraction_definition
      expect(cloned_harvest_definition.transformation_definition).to eq harvest_definition.transformation_definition
    end

    it 'points the clone at the same load definition' do
      harvest_definition.update(load_definition: create(:load_definition, pipeline:, kind: 'secondary_fragment'))

      cloned_harvest_definition = harvest_definition.clone(pipeline_two)

      expect(cloned_harvest_definition.load_definition).to eq harvest_definition.load_definition
    end
  end

  describe "#destroy" do
    let(:pipeline)                  { create(:pipeline)}
    let!(:harvest_definition)       { create(:harvest_definition, pipeline:, extraction_definition:, transformation_definition:, load_definition:) }
    let(:extraction_definition)     { create(:extraction_definition) }
    let(:transformation_definition) { create(:transformation_definition) }
    let(:load_definition)           { create(:load_definition, pipeline:) }

    context 'when the associated Extraction Definition and Transformation Definition were not shared' do
      it 'destroys the Extraction Definition' do
       expect { harvest_definition.destroy }.to change(ExtractionDefinition, :count).by(-1)
      end

      it 'destroys the Transformation Definition' do
        expect { harvest_definition.destroy }.to change(TransformationDefinition, :count).by(-1)
      end

      it 'destroys the Load Definition' do
        expect { harvest_definition.destroy }.to change(LoadDefinition, :count).by(-1)
      end
    end

    context 'when the associated Extraction Definition and Transformation Definition were shared' do
      let!(:harvest_definition_two) { create(:harvest_definition, pipeline:, extraction_definition:, transformation_definition:, load_definition:) }

      it 'does not destroy the Extraction Definition' do
        expect(extraction_definition.shared?).to eq true
        expect { harvest_definition.destroy }.to change(ExtractionDefinition, :count).by(0)
      end

      it 'does not destroy the Transformation Definition' do
        expect(transformation_definition.shared?).to eq true
        expect { harvest_definition.destroy }.to change(TransformationDefinition, :count).by(0)
      end

      it 'does not destroy the Load Definition' do
        expect(load_definition.shared?).to eq true
        expect { harvest_definition.destroy }.to change(LoadDefinition, :count).by(0)
      end
    end

    context "when a harvest definition has previously been run" do
      let!(:destination)        { create(:destination) }
      let!(:pipeline_job)       { create(:pipeline_job, pipeline: pipeline, destination:, harvest_definitions_to_run: [harvest_definition.id.to_s]) }
      let!(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }
      let!(:harvest_report)     { create(:harvest_report, pipeline_job:, harvest_job:) }

      it "destroys the harvest definition" do
        expect { harvest_definition.destroy }.to change(HarvestDefinition, :count).by(-1)
      end

      it "destroys the harvest job" do
        expect { harvest_definition.destroy }.to change(HarvestJob, :count).by(-1)
      end

      it "does not destroy the harvest reports" do
        expect { harvest_definition.destroy }.to change(HarvestReport, :count).by(0)
      end
    end 
  end
end
