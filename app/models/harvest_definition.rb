# frozen_string_literal: true

class HarvestDefinition < ApplicationRecord
  belongs_to :pipeline
  belongs_to :content_source, optional: true

  belongs_to :extraction_definition, optional: true, dependent: :destroy
  belongs_to :extraction_job, optional: true

  belongs_to :transformation_definition, dependent: :destroy, optional: true

  has_many :harvest_jobs, dependent: :destroy

  # before_create :clone_transformation_definition
  # before_create :clone_extraction_definition

  validates :source_id, presence: true
  # validate :extraction_definition_is_a_copy, on: :update
  # validate :transformation_definition_is_a_copy, on: :update

  enum :kind, { harvest: 0, enrichment: 1 }

  after_create do
    self.name = "#{pipeline.name.parameterize}__#{kind}-#{id}"
    save!
  end

  # Creates a safe copy of the provided transformation definition
  # So that edits made to the visible transformation definition
  # do not affect the running harvests / enrichments
  #
  # @return void
  # def clone_transformation_definition
  #   safe_transformation = transformation_definition.dup
  #   count = transformation_definition.copies.count + 1

  #   safe_transformation.name = "[#{count}] #{safe_transformation.name}"
  #   transformation_definition.fields.each do |field|
  #     safe_transformation.fields.push(field.dup)
  #   end

  #   safe_transformation.original_transformation_definition = transformation_definition
  #   safe_transformation.save!
  #   self.transformation_definition = safe_transformation
  # end

  # Updates the safe copy of the transformation definition
  # To match the details of the provided transformation definition
  #
  # @param transformation_definition, a TransformationDefinition instance
  # @return void
  # def update_transformation_definition_clone(transformation_definition)
  #   self.transformation_definition.update(
  #     record_selector: transformation_definition.record_selector,
  #     original_transformation_definition: transformation_definition
  #   )

  #   self.transformation_definition.fields.destroy_all

  #   transformation_definition.fields.each do |field|
  #     self.transformation_definition.fields.push(field.dup)
  #   end
  # end

  # Creates a safe copy of the provided extraction definition
  # So that edits made to the visible extraction definition
  # do not affect the running harvests / enrichments
  #
  # @return void
  # def clone_extraction_definition
  #   safe_extraction = extraction_definition.dup
  #   count = extraction_definition.copies.count + 1

  #   safe_extraction.name = "[#{count}] #{safe_extraction.name}"
  #   safe_extraction.original_extraction_definition = extraction_definition
  #   safe_extraction.save!
  #   self.extraction_definition = safe_extraction
  # end

  # Updates the safe copy of the extraction definition
  # so that it has the same attributes as the provided extraction definition
  #
  # @param extraction_definition, an ExtractionDefinition.instance
  # @return void
  # def update_extraction_definition_clone(extraction_definition)
  #   self.extraction_definition.update(extraction_definition.dup.attributes.except('name').compact)
  #   self.extraction_definition.update(original_extraction_definition: extraction_definition)
  # end

  # def extraction_definition_is_a_copy
  #   return if extraction_definition.copy?

  #   errors.add(:extraction_definition_original, 'Harvest Definition cannot be associated with an original extraction definition')
  # end

  # def transformation_definition_is_a_copy
  #   return if transformation_definition.copy?

  #   errors.add(:transformation_definition_original, 'Harvest Definition cannot be associated with an original transformation definition')
  # end
end
