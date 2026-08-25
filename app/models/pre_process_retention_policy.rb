# frozen_string_literal: true

# The numbers behind the nightly preprocess sweep, read from the `preprocess`
# section of config/retention.yml: keep each pipeline's newest keep_latest
# runs, sweep the rest.
#
# Deliberately separate from ExtractionRetentionPolicy rather than sharing one
# object: the two cleanups answer different questions, and a separate dry_run
# lets one be armed while the other stays disarmed.
class PreProcessRetentionPolicy
  attr_reader :keep_latest

  def self.load
    new(Rails.application.config_for(:retention).fetch(:preprocess).to_h)
  end

  def initialize(config)
    @dry_run = config.fetch(:dry_run)
    @keep_latest = config.fetch(:keep_latest)
  end

  # When true the sweep logs what it would do and deletes nothing.
  def dry_run?
    @dry_run
  end
end
