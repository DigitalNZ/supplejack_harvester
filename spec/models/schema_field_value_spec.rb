require 'rails_helper'

RSpec.describe SchemaFieldValue, type: :model do
  let(:schema) { create(:schema) }
  let(:schema_field) { create(:schema_field, schema:) }
  subject { create(:schema_field_value, value: 'test', schema_field:) }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.value).to eq 'test'
    end

    it { is_expected.to belong_to(:schema_field) }
    it { should have_and_belong_to_many(:fields) }
  end

  describe '#validations' do
    it { is_expected.to validate_presence_of(:value).with_message("can't be blank") }
  end
end
