require 'rails_helper'

RSpec.describe SchemaField, type: :model do
  let(:schema) { create(:schema) }
  subject { create(:schema_field, name: 'internal_identifier', schema:) }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'internal_identifier'
    end

    it { is_expected.to belong_to(:schema) }
    it { is_expected.to have_many(:schema_field_values) }
  end

  describe '#kinds' do
    kinds = { dynamic: 0, fixed: 1 }

    kinds.each do |key, value|
      it "can be #{key}" do
        expect(described_class.new(kind: value).kind).to eq(key.to_s)
      end
    end
  end
end
