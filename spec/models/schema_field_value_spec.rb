require 'rails_helper'

RSpec.describe SchemaFieldValue, type: :model do
  let(:schema) { create(:schema) }
  let(:schema_field) { create(:schema_field, schema:) }
  subject { create(:schema_field_value, name: 'test', schema_field:) }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'test'
    end

    it { is_expected.to belong_to(:schema_field) }
  end

  describe '#validations' do
    it { is_expected.to validate_presence_of(:name).with_message("can't be blank") }
  end
end
