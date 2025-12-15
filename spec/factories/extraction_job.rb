# frozen_string_literal: true

FactoryBot.define do
  factory :extraction_job do
    status { 'queued' }
    kind   { 'full' }
    is_independent_extraction { false }

    updated_at { DateTime.parse('2000-01-15 13:30:00') }
    created_at { DateTime.parse('2000-01-15 13:30:00') }

    extraction_definition
  end
end
