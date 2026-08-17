# frozen_string_literal: true

require 'rails_helper'

# A request parameter that was never evaluated - a dynamic expression left as a static
# parameter - leaves its #{...} in the URL, which the request layer cannot parse.
#
# That used to take five and a half minutes to report, and then blamed the wrong thing:
# Retriable spent its whole backoff on a URL that could never become valid, #extract
# swallowed the error, and #save raised "#extract must be called before #save".
RSpec.describe 'An extraction whose URL cannot be parsed' do
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) do
    create(:extraction_definition, pipeline:, base_url: 'http://localhost:5101/api/v1/shows')
  end
  let(:request) { create(:request, extraction_definition:) }
  let!(:parameter) do
    create(:parameter, kind: 'slug', content_type: 'static', request:,
                       content: %("\#{response['transformed_record']['tvshow_slug']}/seasons"))
  end
  let(:record) { Extraction::ApiRecord.new({ 'transformed_record' => { 'tvshow_slug' => 'the-quiet-archive' } }) }
  let(:extraction) do
    Extraction::EnrichmentExtraction.new(extraction_definition.configured_request, record, 1, '/tmp/unrequestable')
  end

  it 'gives up immediately instead of retrying a URL that cannot become valid' do
    expect(Retriable).not_to receive(:retriable)

    extraction.extract

    expect(extraction.document).to be_nil
    expect(extraction.extraction_error).to be_a URI::Error
  end

  it 'blames the URL and its parameters rather than a missing #extract call' do
    expect { extraction.extract_and_save }
      .to raise_error(/could not be extracted.*bad URI.*check the request's parameters/m)
  end

  it 'says nothing about #extract not having been called' do
    expect { extraction.extract_and_save }.to raise_error do |error|
      expect(error.message).not_to include 'must be called before'
    end
  end
end
