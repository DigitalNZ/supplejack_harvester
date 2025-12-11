# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionDefinition do
  subject! { create(:extraction_definition, pipeline: pipeline1) }

  let!(:pipeline1) { create(:pipeline, name: 'National Library of New Zealand') }
  let!(:pipeline2) { create(:pipeline) }

  describe '#name' do
    it 'autogenerates a sensible name' do
      expect(subject.name).to eq "#{subject.id}_harvest-extraction"
    end
  end

  describe '#validations presence of' do
    context 'when the extraction definition is for a harvest' do
      it { is_expected.to validate_presence_of(:format).with_message("can't be blank") }
      it { is_expected.to validate_presence_of(:base_url).with_message("can't be blank") }
      it { is_expected.to validate_presence_of(:throttle).with_message('is not a number') }

      it { is_expected.not_to validate_presence_of(:destination_id).with_message("can't be blank") }
      it { is_expected.not_to validate_presence_of(:source_id).with_message("can't be blank") }
    end

    context 'when the extraction definition is for an enrichment' do
      subject! { create(:extraction_definition, :enrichment, name: 'Flickr API', destination:, pipeline: pipeline1) }

      let(:destination) { create(:destination) }

      it { is_expected.to validate_presence_of(:throttle).with_message('is not a number') }
      it { is_expected.to validate_presence_of(:destination_id).with_message("can't be blank") }
      it { is_expected.to validate_presence_of(:source_id).with_message("can't be blank") }

      it { is_expected.not_to validate_presence_of(:format).with_message("can't be blank") }
      it { is_expected.not_to validate_presence_of(:base_url).with_message("can't be blank") }
    end

    context 'when the extraction definition needs to be split' do
      subject! { build(:extraction_definition, pipeline: pipeline1, split: true) }

      it { is_expected.to validate_presence_of(:split_selector).with_message("can't be blank") } 
    end
  end

  describe '#validation numericality' do
    it do
      expect(subject).to validate_numericality_of(:throttle)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(60_000)
    end

    it { is_expected.to validate_numericality_of(:page).only_integer }
  end

  describe '#validation' do
    it {
      expect(subject).to validate_inclusion_of(:format).in_array(%w[JSON
                                                                    XML HTML]).with_message('is not included in the list')
    }

    it 'requires a pipeline' do
      extraction_definition = build(:extraction_definition, pipeline: nil)
      expect(extraction_definition).not_to be_valid

      expect(extraction_definition.errors[:pipeline]).to include 'must exist'
    end

    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.with_message('has already been taken') }
  end

  describe '#validations base_url' do
    [
      'http://google.com',
      'http://google.com/',
      'https://google.com/',
      'http://google.com:80',
      'http://google.com:443',
      'http://google.com/hello',
      'http://google.com/hello?',
      'http://google.com/?param=value',
      'http://google.com/page?param=value&param2="value"',
      'http://google.com/page?param=value',
      'http://google.com/page?param[sub_param]=value'
    ].each do |base_url|
      it { is_expected.to allow_value(base_url).for(:base_url) }
    end

    [
      'google',
      'google.com'
    ].each do |base_url|
      it { is_expected.not_to allow_value(base_url).for(:base_url) }
    end
  end

  describe '#associations' do
    subject { create(:extraction_definition, extraction_jobs: [extraction_job]) }

    let(:extraction_job) { create(:extraction_job) }

    it 'has many jobs' do
      expect(subject.extraction_jobs).to include(extraction_job)
    end

    it { is_expected.to have_many(:harvest_definitions) }
    it { is_expected.to have_many(:extraction_jobs) }
    it { is_expected.to have_many(:requests) }
    it { is_expected.to have_many(:parameters) }
    it { is_expected.to have_many(:stop_conditions) }
  end

  describe '#kinds' do
    kinds = { harvest: 0, enrichment: 1 }

    kinds.each do |key, value|
      it "can be #{key}" do
        expect(described_class.new(kind: value).kind).to eq(key.to_s)
      end
    end
  end

  describe '#shared?' do
    let(:pipeline)                  { create(:pipeline) }
    let!(:harvest_definition_one)   { create(:harvest_definition, extraction_definition: shared, pipeline:) }
    let!(:harvest_definition_two)   { create(:harvest_definition, extraction_definition: shared, pipeline:) }
    let!(:harvest_definition_three) { create(:harvest_definition, extraction_definition: standalone, pipeline:) }

    let(:shared)                    { create(:extraction_definition, pipeline:) }
    let(:standalone)                { create(:extraction_definition, pipeline:) }

    it 'returns true if the extraction definition is used in more than one harvest definition' do
      expect(shared.shared?).to be true
    end

    it 'returns false if the extraction definition is only used in one harvest definition' do
      expect(standalone.shared?).to be false
    end
  end

  describe '#clone' do
    let(:pipeline)                  { create(:pipeline) }
    let(:extraction_definition)     { create(:extraction_definition) }
    let!(:request_one)              { create(:request, :figshare_initial_request, extraction_definition:) }
    let!(:request_two)              { create(:request, :figshare_main_request, extraction_definition:) }

    let(:stop_condition_one)        { create(:stop_condition, extraction_definition:) }
    let(:stop_condition_two)        { create(:stop_condition, extraction_definition:) }    

    let(:pipeline_two)               { create(:pipeline) }
    let!(:harvest_definition)        { create(:harvest_definition, extraction_definition:, pipeline:) }
    let!(:harvest_definition_two)    { create(:harvest_definition, extraction_definition:, pipeline:) }

    it 'creates a new Extraction Definition with the same details' do
      cloned_extraction_definition = extraction_definition.clone(pipeline_two, 'clone')

      cloned_extraction_definition.save
      expect(cloned_extraction_definition.requests.count).to eq extraction_definition.requests.count

      cloned_extraction_definition.requests.zip(extraction_definition.requests) do |cloned_request, original_request|
        expect(cloned_request.http_method).to eq original_request.http_method

        expect(cloned_request.parameters.count).to eq original_request.parameters.count

        cloned_request.parameters.zip(original_request.parameters) do |cloned_parameter, original_parameter| 
          expect(cloned_parameter.name).to eq original_parameter.name
          expect(cloned_parameter.content).to eq original_parameter.content
          expect(cloned_parameter.kind).to eq original_parameter.kind
          expect(cloned_parameter.content_type).to eq original_parameter.content_type
        end
      end

      expect(cloned_extraction_definition.stop_conditions).to eq extraction_definition.stop_conditions
    end

    it 'assigns the new ExtractionDefinition to the provided Pipeline' do
      expect(harvest_definition_two.extraction_definition).to eq extraction_definition

      cloned_extraction_definition = extraction_definition.clone(pipeline_two, 'clone')
      cloned_extraction_definition.save
      expect(cloned_extraction_definition.pipeline).to eq pipeline_two
    end

    it 'assigns the provided name to the ExtractionDefinition clone' do
      cloned_extraction_definition = extraction_definition.clone(pipeline_two, 'clone')

      cloned_extraction_definition.save
      expect(cloned_extraction_definition.name).to eq 'clone'
    end
  end

  describe "#destroy" do
    let!(:pipeline_job)       { create(:pipeline_job, pipeline: pipeline1, destination:) }
    let!(:harvest_definition) { create(:harvest_definition, pipeline: pipeline1, extraction_definition: subject) }
    let!(:destination)        { create(:destination) }

    context "when an extraction definition is run as part of a harvest" do
      let!(:extraction_job)     { create(:extraction_job, extraction_definition: subject, harvest_job:)}
      let!(:harvest_job)        { create(:harvest_job, :completed, harvest_definition:, pipeline_job:) }
      let!(:harvest_report)     { create(:harvest_report, pipeline_job:, harvest_job:) }

      it "destroys the extraction definition" do
        expect { subject.destroy }.to change(ExtractionDefinition, :count).by(-1)
      end

      it "destroys the harvest job" do
        expect { subject.destroy }.to change(HarvestJob, :count).by(-1)
      end

      it "does not destroy the harvest reports" do
        expect { subject.destroy }.to change(HarvestReport, :count).by(0)
      end
    end

    context "when an extraction definition doesn't run as part of a harvest" do
      let!(:extraction_job)     { create(:extraction_job, extraction_definition: subject)}

      it "destroys the extraction definition" do
        expect { subject.destroy }.to change(ExtractionDefinition, :count).by(-1)
      end
    end
  end

  describe 'pre-extraction features' do
    let(:pipeline) { create(:pipeline) }

    describe '#pre_extraction' do
      it 'defaults to false' do
        ed = create(:extraction_definition, pipeline:)
        expect(ed.pre_extraction).to be false
      end

      it 'can be set to true' do
        ed = create(:extraction_definition, pipeline:, pre_extraction: true)
        expect(ed.pre_extraction).to be true
      end
    end
  end
end
