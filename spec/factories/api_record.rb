# frozen_string_literal: true

FactoryBot.define do
  factory :api_record, class: 'Extraction::ApiRecord' do
    body do
      { 'id' => 23_029_880,
        'internal_identifier' => 'https://test.govt.nz/notice/id/2004-ln3536' }
    end
    initialize_with { new(attributes) }
  end
end
