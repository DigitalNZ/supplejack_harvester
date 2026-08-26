# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadOptions do
  let(:pipeline) { create(:pipeline) }

  # load_definition: nil so that what the pipeline already writes is only ever what a test
  # sets up: the factory would otherwise give the block one, and #default_priority reads the
  # priorities of every load definition in the pipeline.
  def options_for(block_kind)
    described_class.new(
      create(:harvest_definition, pipeline:, kind: block_kind, source_id: block_kind.to_s, load_definition: nil)
    )
  end

  describe '#kind_options' do
    it 'offers a harvest both fragments, its own record first' do
      expect(options_for(:harvest).kind_options.map(&:last)).to eq %w[primary_fragment secondary_fragment]
    end

    it 'offers a pre-processing block only the file the next block reads' do
      expect(options_for(:preprocess).kind_options.map(&:last)).to eq %w[preprocessed_data]
    end

    it 'labels each with what it does to the record, the enum key alone not saying' do
      expect(options_for(:enrichment).kind_options.first.first).to start_with 'Enrichment –'
    end
  end

  describe '#asks_for_priority?' do
    it 'asks a block that writes a fragment, the priority deciding which one' do
      expect(options_for(:harvest).asks_for_priority?).to be true
    end

    it 'does not ask a pre-processing block, which writes no fragment at all' do
      expect(options_for(:preprocess).asks_for_priority?).to be false
    end
  end

  describe '#asks_for_request_settings?' do
    it 'asks a block that posts to the API, which is what there is a request to size' do
      expect(options_for(:harvest).asks_for_request_settings?).to be true
    end

    it 'does not ask a pre-processing block, which writes a file and posts nothing' do
      expect(options_for(:preprocess).asks_for_request_settings?).to be false
    end
  end


  describe '#asks_for_required_fragment?' do
    it 'asks an enrichment, the only kind that can leave a record partial by not arriving' do
      expect(options_for(:enrichment).asks_for_required_fragment?).to be true
    end

    it 'does not ask a harvest' do
      expect(options_for(:harvest).asks_for_required_fragment?).to be false
    end
  end

  describe '#default_kind' do
    it 'is what the block would have loaded as before it could be told' do
      expect(options_for(:harvest).default_kind).to eq 'primary_fragment'
      expect(options_for(:enrichment).default_kind).to eq 'enrichment'
      expect(options_for(:preprocess).default_kind).to eq 'preprocessed_data'
    end
  end

  describe '#default_priority' do
    it 'is 0 for the kinds that have no choice about it' do
      expect(options_for(:harvest).default_priority).to eq 0
      expect(options_for(:preprocess).default_priority).to eq 0
    end

    # Fragments merge lowest first, so a new one has to sit below every fragment already
    # being written rather than tying with one of them.
    it 'is one below the lowest the pipeline already writes' do
      create(:load_definition, pipeline:, kind: 'enrichment', priority: -3)

      expect(options_for(:enrichment).default_priority).to eq(-4)
    end

    it 'starts at -1 when the pipeline writes nothing below the primary fragment yet' do
      expect(options_for(:enrichment).default_priority).to eq(-1)
    end
  end
end
