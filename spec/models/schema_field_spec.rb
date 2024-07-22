require 'rails_helper'

RSpec.describe SchemaField, type: :model do
  let(:schema) { create(:schema) }
  subject { create(:schema_field, name: 'internal_identifier', schema:) }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'internal_identifier'
    end

    it { is_expected.to belong_to(:schema) }
  end
end
