# frozen_string_literal: true

FactoryBot.define do
  factory :extraction_definition do
    format { 'JSON' }
    base_url { "#{Faker::Internet.url}?param=value" }
    throttle { 0 }
    kind { 0 }

    pagination_type { 'page' }
    page_parameter { 'page' }
    page { 1 }
    per_page_parameter { 'per_page' }
    per_page { 50 }
    total_selector { '$.totalObjects' }

    trait :ngataonga do
      name { 'api.ngataonga.org.nz' }
      base_url { 'http://api.ngataonga.org.nz/records.json/?api_key=MYAPIKEY&and[has_media]=true' }
      throttle { 0 }
      page_parameter { 'page' }
      page { 1 }
      per_page_parameter { 'per_page' }
      per_page { 50 }
      total_selector { '$..result_count' }
    end

    trait :figshare do
      name     { 'api.figshare.com' }
      format   { 'JSON' }
      base_url { 'https://api.figshare.com/v1/articles/search?search_for=zealand' }
      throttle { 1000 }
      pagination_type { 'page' }
      page_parameter { 'page' }
      page { 1 }
      per_page { 10 }
      total_selector { '$.items_found' }
      per_page_parameter { 'itemsPerPage' }
    end

    association :pipeline

    trait :harvest do
      kind { 0 }
    end

    trait :enrichment do
      kind { 1 }
      source_id { 'test' }
      enrichment_url { '"https://api.figshare.com/v1/articles/#{record[\'dc_identifier\'].first}"' }
      throttle { 1000 }
    end
  end
end
