# frozen_string_literal: true

# Used to store the information for running an extraction
#
class ExtractionDefinition < ApplicationRecord
  FORMATS = %w[JSON XML HTML ARCHIVE_JSON].freeze

  # The destination is used for Enrichment Extractions
  # To know where to pull the records that are to be enriched from
  belongs_to :destination, optional: true
  belongs_to :pipeline
  belongs_to :last_edited_by, class_name: 'User', optional: true

  has_many :harvest_definitions, dependent: :nullify
  has_many :extraction_jobs, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_many :parameters, through: :requests
  has_many :stop_conditions, dependent: :destroy

  enum :kind, { harvest: 0, enrichment: 1 }

  after_create do
    if name.blank?
      self.name = "#{id}_#{kind}-extraction"
      save!
    end
  end

  # find good regex or another implementation
  FORMAT_SELECTOR_REGEX_MAP = {
    JSON: /^\$\./,
    XML: %r{^/},
    HTML: %r{^/},
    OAI: %r{^/}
  }.freeze

  validates :name, uniqueness: true
  validates :split_selector, presence: true, if: :split?

  validates :throttle, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 60_000 }

  validates :page, numericality: { only_integer: true }

  # Harvest related validation
  with_options if: :harvest? do
    validates :format, presence: true, inclusion: { in: FORMATS }
    validates :base_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  end

  with_options presence: true, if: :enrichment? do
    validates :destination_id
    validates :source_id
  end

  def to_h
    {
      id:,
      name:
    }
  end

  def json?
    format.in? %w[JSON ARCHIVE_JSON]
  end

  def shared?
    @shared = harvest_definitions.count > 1 if @shared.nil?
    @shared
  end

  serialize :link_selectors, type: Array

  # Get link selector for a specific depth level
  def link_selector_for_depth(depth)
    return nil unless pre_extraction?
    return nil unless valid_link_selectors?

    selector_entry = find_selector_entry_by_depth(depth)
    extract_selector_from_entry(selector_entry)
  end

  def link_selectors_hash
    return {} unless valid_link_selectors?

    link_selectors.each_with_object({}) do |entry, hash|
      add_entry_to_hash(entry, hash)
    end
  end

  private

  def valid_link_selectors?
    link_selectors.present? && link_selectors.is_a?(Array)
  end

  def find_selector_entry_by_depth(depth)
    link_selectors.find do |entry|
      entry_depth = extract_depth_from_entry(entry)
      entry_depth&.to_i == depth.to_i
    end
  end

  def extract_depth_from_entry(entry)
    return nil unless entry.is_a?(Hash)

    entry['depth'] || entry[:depth]
  end

  def extract_selector_from_entry(entry)
    return nil unless entry.is_a?(Hash)

    entry['selector'] || entry[:selector]
  end

  def add_entry_to_hash(entry, hash)
    return unless entry.is_a?(Hash)

    depth = extract_depth_from_entry(entry)
    selector = extract_selector_from_entry(entry)
    hash[depth.to_s] = selector if depth.present? && selector.present?
  end

  public

  # rubocop:disable Metrics/AbcSize
  def clone(pipeline, name)
    cloned_extraction_definition = ExtractionDefinition.new(dup.attributes.merge(name:, pipeline:))

    requests.each do |request|
      cloned_request = request.dup
      request.parameters.each { |parameter| cloned_request.parameters << parameter.dup }

      cloned_extraction_definition.requests << cloned_request
    end

    stop_conditions.each do |stop_condition|
      cloned_extraction_definition.stop_conditions << stop_condition.dup
    end

    cloned_extraction_definition
  end
  # rubocop:enable Metrics/AbcSize
end
