require 'rails_helper'

RSpec.describe Schema, type: :model do
  subject { create(:schema, name: 'test') }

  describe '#attributes' do
    it 'has a name' do
      expect(subject.name).to eq 'test' 
    end
  end
end
