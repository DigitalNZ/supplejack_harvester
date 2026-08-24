# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tag do
  describe 'validations' do
    subject { build(:tag) }

    it { is_expected.to validate_presence_of(:name).with_message("can't be blank") }

    # validate_uniqueness_of is no use here: it saves its existing record without
    # validations, which skips the callback deriving the slug, and the NOT NULL column
    # rejects it before the matcher gets to compare anything.
    it 'rejects a duplicate name whatever its case' do
      create(:tag, name: 'Production')
      tag = build(:tag, name: 'production')

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include 'has already been taken'
    end
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(50) }

    it 'rejects a name with nothing sluggable in it' do
      tag = build(:tag, name: '!!!')

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include I18n.t('tag.validations.name_format')
    end

    it 'rejects a name of one character' do
      tag = build(:tag, name: 'a')

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include 'is too short (minimum is 2 characters)'
    end

    it 'accepts a name of two characters' do
      expect(build(:tag, name: 'NZ')).to be_valid
    end

    # Blank names are the presence validation's business; a length error on top of it
    # would report the same mistake twice.
    it 'reports a blank name once' do
      tag = build(:tag, name: '')

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to eq ["can't be blank"]
    end

    it 'rejects a name that reduces to the same slug as an existing tag' do
      create(:tag, name: 'Production')
      tag = build(:tag, name: 'Production!')

      expect(tag).not_to be_valid
      expect(tag.errors[:slug]).to include 'has already been taken'
    end

  end

  describe '#name' do
    it 'is squished, so surrounding and repeated whitespace does not reach the card' do
      expect(create(:tag, name: "  National   Library  \n").name).to eq 'National Library'
    end

    it 'treats a padded spelling of an existing name as the duplicate name it is' do
      create(:tag, name: 'Production')
      tag = build(:tag, name: '  Production  ')

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include 'has already been taken'
    end

    it 'rejects a name that is nothing but whitespace' do
      tag = build(:tag, name: '   ')

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include "can't be blank"
    end

    it 'is findable without the caller having to tidy the name first' do
      tag = create(:tag, name: 'Production')

      expect(described_class.find_by(name: '  Production  ')).to eq tag
    end
  end

  describe '#slug' do
    it 'is derived from the name' do
      expect(create(:tag, name: 'National Library NZ').slug).to eq 'national-library-nz'
    end

    it 'follows the name when the tag is renamed' do
      tag = create(:tag, name: 'Staging')

      tag.update(name: 'Pre production')

      expect(tag.slug).to eq 'pre-production'
    end
  end

  describe '.from_names' do
    it 'reuses an existing tag rather than making a second one' do
      existing = create(:tag, name: 'Production')

      expect(described_class.from_names(['Production'])).to eq [existing]
    end

    # The names come from a text field, so they arrive however they were typed.
    it 'finds an existing tag however the name was spelled' do
      existing = create(:tag, name: 'Production')

      expect(described_class.from_names(['  pRoDuCtIoN '])).to eq [existing]
    end

    it 'creates the tags that do not exist yet' do
      expect { described_class.from_names(%w[Museum Audio]) }.to change(described_class, :count).by(2)
      expect(described_class.ordered.pluck(:name)).to eq %w[Audio Museum]
    end

    it 'ignores blanks and takes each tag once' do
      tags = described_class.from_names(['Museum', '', '  ', nil, 'museum', 'Museum!'])

      expect(tags.map(&:name)).to eq ['Museum']
    end

    it 'takes nil for no tags at all' do
      expect(described_class.from_names(nil)).to eq []
    end

    # The caller reports these rather than saving a pipeline half way.
    it 'returns an unsaved tag carrying its errors when a name cannot be saved' do
      tags = described_class.from_names(['!!!'])

      expect(tags.first).not_to be_persisted
      expect(tags.first.errors[:name]).to include I18n.t('tag.validations.name_format')
    end
  end

  describe 'associations' do
    it 'has_many pipelines through pipeline_tags' do
      tag = create(:tag)
      pipeline = create(:pipeline)
      create(:pipeline_tag, pipeline:, tag:)

      expect(tag.pipelines).to eq [pipeline]
    end

    it 'destroys its pipeline_tags but not the pipelines' do
      tag = create(:tag)
      pipeline = create(:pipeline)
      create(:pipeline_tag, pipeline:, tag:)

      expect { tag.destroy }.to change(PipelineTag, :count).by(-1)
      expect(pipeline.reload).to be_persisted
    end
  end

  describe '.ordered' do
    it 'sorts by name' do
      second = create(:tag, name: 'Beta')
      first = create(:tag, name: 'Alpha')

      expect(described_class.ordered).to eq [first, second]
    end
  end
end
