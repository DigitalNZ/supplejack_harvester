require 'rails_helper'

RSpec.describe Schema, type: :model do
  subject { create(:schema, name: 'test', description: 'fields for the API') }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'test' 
    end

    it 'has a description' do
      expect(subject.description).to eq 'fields for the API'
    end

    it { is_expected.to have_many(:schema_fields) }
  end

  describe '#validations' do
    it { is_expected.to validate_presence_of(:name).with_message("can't be blank") }
  end
end
