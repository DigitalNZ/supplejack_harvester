# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_definition do
    name { Faker::Company.name }
    source_id { 'test' }

    association :pipeline
    extraction_definition
    transformation_definition

    # A block cannot run without one (BlockConfiguration#missing_definitions), so the default is
    # the kind this block would have loaded as before load definitions existed. Skipped when the
    # caller says anything about the load definition, so that load_definition: nil means what it
    # says - the fallback specs depend on asking for a block without one. The block's own kind is
    # read off the built record rather than the evaluator, so an enum trait naming it still wins.
    after(:build) do |definition, evaluator|
      next if evaluator.__override_names__.include?(:load_definition)

      default_kind = LoadDefinition.default_kind_for_block_kind(definition.kind.to_s)

      definition.load_definition = default_kind && build(:load_definition, pipeline: definition.pipeline,
                                                                          kind: default_kind)
    end
  end
end
