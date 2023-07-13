# frozen_string_literal: true

class TransformationDefinition < ApplicationRecord
  belongs_to :extraction_job # used for previewing, needs to be refactored
  belongs_to :pipeline

  has_many :fields

  scope :originals, -> { where(original_transformation_definition: nil) }

  enum :kind, { harvest: 0, enrichment: 1 }

  validates :record_selector, presence: true
  validate :cannot_be_a_copy_of_self

  after_create do
    self.name = "#{pipeline.name.parameterize}__#{kind}-transformation-#{id}"
    save!
  end

  # feature allows editing a transformation definition without impacting a running harvest
  belongs_to(
    :original_transformation_definition,
    class_name: 'TransformationDefinition',
    optional: true
  )

  has_many(
    :copies,
    class_name: 'TransformationDefinition',
    foreign_key: 'original_transformation_definition_id',
    inverse_of: 'original_transformation_definition'
  )

  # Returns the records from the job based on the given record_selector
  # Used for previewing, needs to be refactored
  #
  # @return Array
  def records(page = 1)
    return [] if record_selector.blank? || extraction_job.documents[page].nil?

    if extraction_job.extraction_definition.format == 'HTML'
      Nokogiri::HTML(extraction_job.documents[page].body)
        .xpath(record_selector)
        .map(&:to_xml)
    elsif extraction_job.extraction_definition.format == 'XML'
      Nokogiri::XML(extraction_job.documents[page].body)
        .xpath(record_selector)
        .map(&:to_xml)
    elsif extraction_job.extraction_definition.format == 'JSON'
      JsonPath.new(record_selector)
              .on(extraction_job.documents[page].body)
              .flatten
    end
  end

  def copy?
    original_transformation_definition.present?
  end

  def cannot_be_a_copy_of_self
    if original_transformation_definition == self
      errors.add(:copy, 'Transformation Definition cannot be a copy of itself')
    end
  end

  def to_h
    {
      id: id,
      name: name
    }
  end
end
