# frozen_string_literal: true

FactoryBot.define do
  factory :load_definition do
    pipeline
    kind { 'primary_fragment' }

    # A secondary fragment at priority 0 writes the primary fragment instead, which the model
    # refuses, so the default priority follows whichever kind the caller asks for.
    priority { kind.to_s == 'secondary_fragment' ? -1 : 0 }
  end
end
