# frozen_string_literal: true

# The numbers behind the nightly preprocess sweep, read from the `preprocess`
# section of config/retention.yml.
#
# Deliberately separate from ExtractionRetentionPolicy rather than sharing one
# object: the two cleanups answer different questions, and a separate dry_run
# lets one be armed while the other stays disarmed.
class PreProcessRetentionPolicy
  attr_reader :min_age_months, :max_age_months

  def self.load
    new(Rails.application.config_for(:retention).fetch(:preprocess).to_h)
  end

  def initialize(config)
    @dry_run = config.fetch(:dry_run)
    @min_age_months = config.fetch(:min_age_months)
    @max_age_months = config.fetch(:max_age_months)
  end

  # When true the sweep logs what it would do and deletes nothing.
  def dry_run?
    @dry_run
  end

  # Output of a finished run created before this is old enough to sweep.
  def min_age_cutoff
    min_age_months.months.ago
  end

  # Output created before this is swept whatever the run's status.
  def max_age_cutoff
    max_age_months.months.ago
  end
end
