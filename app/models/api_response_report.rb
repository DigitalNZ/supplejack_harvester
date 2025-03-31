# frozen_string_literal: true

class ApiResponseReport < ApplicationRecord
  include Status

  belongs_to :automation_step

  validates :status, presence: true

  def display_name
    "API Response #{id}"
  end

  def successful?
    status == 'completed'
  end

  def failed?
    status == 'errored'
  end

  def queued?
    status == 'queued'
  end
end
