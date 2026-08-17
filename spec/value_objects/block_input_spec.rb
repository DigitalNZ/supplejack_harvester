# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlockInput do
  describe '.parse' do
    it 'parses a fresh input' do
      input = described_class.parse('fresh')

      expect(input).to be_fresh
      expect(input.to_s).to eq 'fresh'
    end

    it 'parses an existing extraction job' do
      input = described_class.parse('extraction_job:987')

      expect(input).to be_extraction_job
      expect(input.extraction_job_id).to eq 987
    end

    it 'parses pre-processed output from a run' do
      input = described_class.parse('preprocess_output:44')

      expect(input).to be_preprocess_output
      expect(input).not_to be_latest
      expect(input.pipeline_job_id).to eq 44
    end

    it 'parses the latest pre-processed output' do
      input = described_class.parse('preprocess_output:latest')

      expect(input).to be_preprocess_output
      expect(input).to be_latest
      expect(input.pipeline_job_id).to be_nil
    end

    # These all come from user-submitted params, and the safe reading of anything we
    # do not understand is "run this block the normal way".
    it 'falls back to fresh for unknown kinds, missing references and blanks' do
      expect(described_class.parse('nonsense:1')).to be_fresh
      expect(described_class.parse('preprocess_output')).to be_fresh
      expect(described_class.parse('extraction_job:')).to be_fresh
      expect(described_class.parse(nil)).to be_fresh
      expect(described_class.parse('')).to be_fresh
    end
  end

  describe '#to_s' do
    it 'round trips through parse' do
      %w[fresh extraction_job:987 preprocess_output:44 preprocess_output:latest].each do |value|
        expect(described_class.parse(value).to_s).to eq value
      end
    end
  end
end
