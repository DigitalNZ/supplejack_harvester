# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CardsHelper do
  describe '#extraction_card_subtitle' do
    let(:pipeline) { create(:pipeline) }
    let(:extraction_definition) { create(:extraction_definition, pipeline:) }

    it 'counts the pages of the newest full extraction' do
      job = create(:extraction_job, extraction_definition:)
      FileUtils.mkdir_p("#{job.extraction_folder}/1")
      File.write("#{job.extraction_folder}/1/full__000000001.json", '{}')

      expect(helper.extraction_card_subtitle(extraction_definition)).to eq '1 page'
    end

    it 'shows no page count once the extracted data has been purged' do
      job = create(:extraction_job, extraction_definition:)
      job.purge!

      expect(helper.extraction_card_subtitle(extraction_definition)).to eq ''
    end
  end
end
