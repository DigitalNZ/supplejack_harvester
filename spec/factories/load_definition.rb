# frozen_string_literal: true

FactoryBot.define do
  factory :load_definition do
    pipeline
    kind { 'primary_fragment' }

    # A secondary fragment or an enrichment at priority 0 writes the primary fragment instead,
    # which the model refuses, so the default priority follows whichever kind is asked for.
    priority { %w[secondary_fragment enrichment].include?(kind.to_s) ? -1 : 0 }
  end
end
