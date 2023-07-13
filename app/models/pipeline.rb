# frozen_string_literal: true

class Pipeline < ApplicationRecord
  has_many :harvest_definitions

  validates :name, presence: true

  def harvest
    harvest_definitions.find(&:harvest?)
  end

  def enrichments
    harvest_definitions.select(&:enrichment?)
  end
end
