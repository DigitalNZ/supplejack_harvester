# frozen_string_literal: true

# Used to store information about a Transformation Job
class TransformationJob < ApplicationRecord
  include Job

  belongs_to :extraction_job
  belongs_to :transformation_definition
  belongs_to :harvest_job, optional: true

  after_create do
    self.name = "#{transformation_definition.name}__job-#{id}"
    save!
  end

  # Returns the records from the job based on the given record_selector
  #
  # @return Array
  def records(page = 1)
    return [] if transformation_definition.record_selector.blank? || extraction_job.documents[page].nil?

    if transformation_definition.extraction_job.format == 'HTML'
      Nokogiri::HTML(extraction_job.documents[page].body)
        .xpath(transformation_definition.record_selector)
        .map(&:to_xml)
    elsif transformation_definition.extraction_job.format == 'XML'
      Nokogiri::XML(extraction_job.documents[page].body)
        .xpath(transformation_definition.record_selector)
        .map(&:to_xml)
    elsif transformation_definition.extraction_job.format == 'JSON'
      JsonPath.new(transformation_definition.record_selector)
              .on(extraction_job.documents[page].body)
              .flatten
    end

  end
end
