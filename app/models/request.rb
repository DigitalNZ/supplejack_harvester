# frozen_string_literal: true

class Request < ApplicationRecord
  belongs_to :extraction_definition
  has_many   :parameters, dependent: :destroy

  validates :http_method, presence: true

  delegate :base_url, to: :extraction_definition
  delegate :format,   to: :extraction_definition

  enum :http_method, { GET: 0, POST: 1, PUT: 2, PATCH: 3, DELETE: 4 }

  def url(response = nil)
    return base_url if slug(response).empty?

    "#{base_url}/#{slug(response)}"
  end

  def query_parameters(response = nil)
    parameters
      .query
      .map { |parameter| parameter.evaluate(response) }
      .map(&:to_h)
      .reduce(&:merge)
  end

  def headers(response = nil)
    parameters
      .header
      .map { |paramater| paramater.evaluate(response) }
      .map(&:to_h)
      .reduce(&:merge)
  end

  def to_h
    {
      id:, created_at:, updated_at:, http_method:, base_url:, url:, format:,
      preview: {
        url: nil, request_headers: nil, response_headers: nil, status: nil, body: nil
      }
    }
  end

  def first_request?
    extraction_definition.requests.first.id == id
  end

  private

  def slug(response = nil)
    parameters
      .slug
      .map { |parameter| parameter.evaluate(response) }
      .map(&:content)
      .join('/')
  end
end
