# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractionParams do
  subject { described_class.new(extraction_definition, extraction_job, harvest_job, api_record, page) }

  let(:extraction_definition) { double('ExtractionDefinition') }
  let(:extraction_job) { double('ExtractionJob') }
  let(:harvest_job) { double('HarvestJob') }
  let(:api_record) { double('APIRecord') }
  let(:page) { double('Page') }
end
