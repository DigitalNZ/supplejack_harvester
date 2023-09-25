# frozen_string_literal: true

FactoryBot.define do
  factory :extraction_definition do
    format { 'JSON' }
    base_url { Faker::Internet.url.to_s }
    throttle { 0 }
    kind { 0 }
    per_page { 50 }
    total_selector { '$.totalObjects' }
    page { 1 }
    paginated { false }

    trait :figshare do
      name     { 'api.figshare.com' }
      format   { 'JSON' }
      base_url { 'https://api.figshare.com' }
      throttle { 1000 }
      page { 1 }
      total_selector { '$.items_found' }
      per_page { 10 }
      paginated { true }
    end

    trait :harvest do
      kind { 0 }
    end

    trait :enrichment do
      kind { 1 }
      source_id { 'test' }
      # rubocop:disable Lint/InterpolationCheck
      enrichment_url { '"https://api.figshare.com/v1/articles/#{record["dc_identifier"].first}"' }
      # rubocop:enable Lint/InterpolationCheck
      throttle { 1000 }
    end

    pipeline
  end
end
