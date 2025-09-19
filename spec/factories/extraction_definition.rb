# frozen_string_literal: true

FactoryBot.define do
  factory :extraction_definition do
    format { 'JSON' }
    base_url { Faker::Internet.url.to_s }
    throttle { 0 }
    kind { 0 }
    per_page { 50 }
    paginated { false }
    follow_redirects { true }

    trait :figshare do
      name     { 'api.figshare.com' }
      format   { 'JSON' }
      base_url { 'https://api.figshare.com' }
      throttle { 1000 }
      page { 1 }
      paginated { true }
    end

    trait :harvest do
      kind { 0 }
    end

    trait :no_follow do
      follow_redirects { false }
    end    

    trait :enrichment do
      kind { 1 }
      source_id { 'test' }
      base_url { 'https://api.figshare.com/v1/articles' }
      total_selector { '$.meta.total_pages' }
      per_page { 20 }
    end

    pipeline
  end
end
