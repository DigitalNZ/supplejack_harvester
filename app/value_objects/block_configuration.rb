# frozen_string_literal: true

# Whether a block's extraction, transformation and load definitions agree with each other,
# and in what words they do not. It lives outside the three of them because no one of them
# can answer it alone: a load definition saying it writes a secondary fragment is only wrong
# in the company of a transformation that never sets internal_identifier.
#
# The wording is written to follow "Cannot run:" in the Run modal. A disabled checkbox with
# nothing beside it is little help when the problem is a disagreement rather than a gap.
class BlockConfiguration
  def initialize(definition)
    @definition = definition
  end

  def problems
    missing_definitions + load_problems
  end

  # Just the ways this block's definitions contradict each other. A missing extraction or
  # transformation already shows on the pipeline page as an "+ Add ..." card, so repeating it
  # would only add noise to a pipeline that is still being built; a load definition
  # disagreeing with a transformation shows nowhere at all.
  def load_problems
    problems = []

    if preprocess? && load_kind != 'file'
      problems << 'it is a pre-processing block, so it has to write a file for the next block to read'
    end

    problems + problems_for_load_kind
  end

  private

  attr_reader :definition

  delegate :extraction_definition, :transformation_definition, :load_kind, :preprocess?, to: :definition

  def missing_definitions
    problems = []

    problems << 'it has no extraction definition' if extraction_definition.blank?

    if transformation_definition.blank?
      problems << 'it has no transformation definition'
    elsif transformation_definition.fields.empty?
      problems << 'its transformation has no fields'
    end

    problems
  end

  # Nothing here checks an enrichment against its extraction. The fragments endpoint needs a
  # record id, and it is tempting to require an enrichment extraction to supply one, but
  # ExtractionWorker#iterate_previous? also hands an api_record to a block at a position past
  # the first and to one reading pre-processed output. Ruling those out would make pipelines
  # that run today unrunnable, which is worse than the misconfiguration it would catch.
  def problems_for_load_kind
    case load_kind
    when 'secondary_fragment' then secondary_fragment_problems
    when 'file' then file_problems
    else []
    end
  end

  # A secondary fragment is written by internal_identifier, and nothing else in the payload
  # identifies the record: without that field the destination reads the identifier as nil and
  # creates a record rather than tagging the one that is already there.
  def secondary_fragment_problems
    return [] if transformation_definition.blank?

    problems = []

    unless sets_internal_identifier?
      problems << 'it writes a secondary fragment, so its transformation has to set internal_identifier'
    end

    if transformation_definition.fields.any?(&:delete_if?)
      problems << 'it writes a secondary fragment, so its transformation\'s delete_if rules cannot be ' \
                  'honoured - a fragment going away is not the record going away'
    end

    problems
  end

  def sets_internal_identifier?
    value_field_names.include?('internal_identifier')
  end

  # Only the fields that set a value - a reject_if or delete_if rule has a name too.
  def value_field_names
    transformation_definition.fields.select(&:field?).map(&:name)
  end

  def file_problems
    return [] if preprocess?

    ['only a pre-processing block can write a file for the next block to read']
  end
end
