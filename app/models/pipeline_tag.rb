# frozen_string_literal: true

class PipelineTag < ApplicationRecord
  belongs_to :pipeline
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :pipeline_id }
end
