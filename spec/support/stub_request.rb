# frozen_string_literal: true

require 'webmock/rspec'

WebMock.disable_net_connect!(
  allow: [
    'https://chromedriver.storage.googleapis.com',
    'https://googlechromelabs.github.io',
    'https://edgedl.me.gvt1.com',
    'https://storage.googleapis.com'
  ],
  allow_localhost: true
)

RSpec.configure do |config|
  config.before(:suite) do
    FileUtils.rm Dir.glob("#{ExtractionJob::EXTRACTIONS_FOLDER}/*/tmp/*")
    FileUtils.rmdir Dir.glob("#{ExtractionJob::EXTRACTIONS_FOLDER}/*/tmp")
    FileUtils.rm Dir.glob("#{ExtractionJob::EXTRACTIONS_FOLDER}/*/*")
    FileUtils.rmdir Dir.glob("#{ExtractionJob::EXTRACTIONS_FOLDER}/*")
  end
end

def fake_response(filename)
  path = Rails.root.join("spec/stub_responses/#{filename}.yaml")
  YAML.load_file(path)
end

def fake_json_headers
  {
    'Accept' => '*/*',
    'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
    'Content-Type' => 'application/json',
    'User-Agent' => 'Supplejack Harvester v2.0'
  }
end

def stub_figshare_enrichments(ids, fake_response_name)
  ids.each do |article_id|
    stub_request(:get, "https://api.figshare.com/v1/articles/#{article_id}")
      .with(headers: fake_json_headers)
      .to_return(fake_response(fake_response_name))
  end
end

def stub_figshare_requests(destination, page, ids, fake_response_name)
  stub_request(:get, "#{destination.url}/harvester/records")
    .with(
      query: {
        'api_key' => 'testkey',
        'search' => { 'status' => 'active', 'fragments.source_id' => 'test' },
        'search_options' => { 'page' => page, 'per_page' => 100 }
      },
      headers: fake_json_headers
    ).to_return(fake_response("test_api_records_#{page}"))

  stub_figshare_enrichments(ids, fake_response_name)
end

def stub_figshare_enrichment_page1(destination)
  stub_figshare_requests(
    destination, 1,
    [
      23_029_880, 23_029_811, 23_029_790, 23_029_787, 23_029_784, 23_029_733, 23_029_685, 23_029_673, 23_029_661,
      23_029_634, 23_072_123, 23_072_120, 23_072_033, 23_071_937, 23_071_886, 23_071_577, 23_071_553, 23_071_328,
      23_071_295, 23_071_220
    ], 'figshare_enrichment_1'
  )
end

def stub_figshare_enrichment_page2(destination)
  stub_figshare_requests(
    destination, 2,
    [
      23_071_181, 23_071_178, 23_071_055, 23_070_764, 23_070_638, 23_070_551, 23_070_341, 23_070_317, 23_070_134,
      23_069_885, 23_069_813, 23_069_708, 23_069_609, 23_069_582, 23_069_567, 23_069_555, 23_069_426, 23_069_324,
      23_069_303, 23_068_361
    ], 'figshare_enrichment_1'
  )
end

def stub_failed_figshare_enrichment_page1(destination)
  stub_figshare_requests(
    destination, 1,
    [
      23_029_880, 23_029_811, 23_029_790, 23_029_787, 23_029_784, 23_029_733, 23_029_685, 23_029_673, 23_029_661,
      23_029_634, 23_072_123, 23_072_120, 23_072_033, 23_071_937, 23_071_886, 23_071_577, 23_071_553, 23_071_328,
      23_071_295, 23_071_220
    ],
    'failed_figshare_enrichment_1'
  )
end

def stub_failed_figshare_enrichment_page2(destination)
  stub_figshare_requests(
    destination, 2,
    [
      23_029_880, 23_029_811, 23_029_790, 23_029_787, 23_029_784, 23_029_733, 23_029_685, 23_029_673, 23_029_661,
      23_029_634, 23_072_123, 23_072_120, 23_072_033, 23_071_937, 23_071_886, 23_071_577, 23_071_553, 23_071_328,
      23_071_295, 23_071_220
    ],
    'failed_figshare_enrichment_1'
  )
end
