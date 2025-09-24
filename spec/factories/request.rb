# frozen_string_literal: true

FactoryBot.define do
  factory :request do
    http_method { 'GET' }

    extraction_definition

    trait :figshare_initial_request do
      after(:create) do |request|
        create(:parameter, content: 'v1',       kind: 'slug', request:)
        create(:parameter, content: 'articles', kind: 'slug', request:)
        create(:parameter, content: 'search',   kind: 'slug', request:)

        create(:parameter, name: 'search_for',   content: 'zealand', request:)
        create(:parameter, name: 'page',         content: '1', request:)
        create(:parameter, name: 'itemsPerPage', content: '10', request:)
      end
    end

    trait :figshare_main_request do
      after(:create) do |request|
        create(:parameter, content: 'v1',       kind: 'slug', request:)
        create(:parameter, content: 'articles', kind: 'slug', request:)
        create(:parameter, content: 'search',   kind: 'slug', request:)

        create(:parameter, name: 'search_for',   content: 'zealand', request:)
        create(:parameter, name: 'page',         content: "JSON.parse(response.body)['page_nr'] + 1", request:,
                           content_type: 1)
        create(:parameter, name: 'itemsPerPage', content: '10', request:)
      end
    end
  end

  trait :inaturalist_initial_request do
    after(:create) do |request|
      create(:parameter, name: 'per_page',   content: '30', request:)
      create(:parameter, name: 'id_above',   content: '0', request:)
    end
  end

  trait :inaturalist_main_request do
    after(:create) do |request|
      create(:parameter, name: 'per_page',   content: '30', request:)
      create(:parameter, name: 'id_above',   content: 'JsonPath.new("$.results[(@.length-1)].id").on(response.body).first',
                         request:, content_type: 1)
    end
  end

  trait :freesound_initial_request do
    after(:create) do |request|
      create(:parameter, name: 'page', content: '1', request:)
      create(:parameter, name: 'page_size', content: '50', request:)
    end
  end

  trait :freesound_main_request do
    after(:create) do |request|
      create(
        :parameter,
        name: 'page',
        content: 'Nokogiri::HTML.parse(response.body).at_xpath(\'./html/body/root/next\')' \
                 '.content.match(/.+page=(?<page>.+?)&/)[:page]',
        request:,
        content_type: 1
      )
      create(:parameter, name: 'page_size', content: '50', request:)
    end
  end

  trait :trove_initial_request do
    after(:create) do |request|
      create(:parameter, name: 'n',   content: '100', request:)
      create(:parameter, name: 's',   content: '*', request:)
    end
  end

  trait :trove_main_request do
    after(:create) do |request|
      create(:parameter, name: 'n',   content: '100', request:)
      create(:parameter, name: 's',   content: 'Nokogiri::XML.parse(response.body).at_xpath(\'//records/@nextStart\')',
                         request:, content_type: 1)
    end
  end
end
