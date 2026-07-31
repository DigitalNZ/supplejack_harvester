# frozen_string_literal: true

# The numbers behind the nightly extraction cleanup, read from
# config/extraction_lifecycle.yml.
#
# Deliberately shaped like a future database-backed policy record: when
# retention becomes editable in the UI, only .load needs to change.
class ExtractionLifecyclePolicy
  attr_reader :batch_limit, :min_age_months, :keep_latest, :max_age_months,
              :excluded_extraction_definition_ids

  def self.load
    new(Rails.application.config_for(:extraction_lifecycle).to_h)
  end

  def initialize(config)
    @dry_run = config.fetch(:dry_run)
    @batch_limit = config.fetch(:batch_limit)
    @min_age_months = config.fetch(:min_age_months)
    @keep_latest = config.fetch(:keep_latest)
    @max_age_months = config.fetch(:max_age_months)
    @excluded_extraction_definition_ids = config.fetch(:excluded_extraction_definition_ids, [])
  end

  # When true the cleanup logs what it would do and deletes nothing.
  def dry_run?
    @dry_run
  end

  # Extractions created before this are old enough to be considered.
  def min_age_cutoff
    min_age_months.months.ago
  end

  # Extractions created before this are purged whatever their position.
  def max_age_cutoff
    max_age_months.months.ago
  end
end
