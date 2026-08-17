# frozen_string_literal: true

require 'rails_helper'

# The editor is handed its initial Redux state in the page's data-props. Two of its
# flags mark which parameter and which stop condition the editor opens on, and working
# them out used to consult the database once per parameter and once per condition.
RSpec.describe 'The extraction editor state' do
  let(:user)     { create(:user) }
  let(:pipeline) { create(:pipeline) }
  let(:extraction_definition) { create(:extraction_definition, pipeline:) }
  let!(:harvest_definition) do
    create(:harvest_definition, pipeline:, extraction_definition:)
  end
  let!(:first_request)      { create(:request, extraction_definition:) }
  let!(:subsequent_request) { create(:request, extraction_definition:) }

  before { sign_in(user) }

  def state
    get pipeline_harvest_definition_extraction_definition_path(pipeline, harvest_definition, extraction_definition)

    JSON.parse(Nokogiri::HTML(response.body).at_css('#js-extraction-app')['data-props'])
  end

  def displayed_ids(slice)
    slice['entities'].values.select { |entity| entity['displayed'] }.map { |entity| entity['id'] }
  end

  describe 'which parameter is displayed' do
    let!(:on_first)      { create(:parameter, request: first_request, name: 'one') }
    let!(:also_on_first) { create(:parameter, request: first_request, name: 'two') }
    let!(:on_subsequent) { create(:parameter, request: subsequent_request, name: 'three') }

    it 'marks the parameters belonging to the first request' do
      expect(displayed_ids(state['ui']['parameters'])).to contain_exactly(on_first.id, also_on_first.id)
    end
  end

  describe 'which stop condition is displayed' do
    let!(:first_condition) { create(:stop_condition, extraction_definition:) }
    let!(:last_condition)  { create(:stop_condition, extraction_definition:) }

    it 'marks the last one' do
      expect(displayed_ids(state['ui']['stopConditions'])).to eq [last_condition.id]
    end
  end

  # Bullet reported this as an N+1 on Parameter => [:request]. Rather than pin a total
  # query count, which moves with anything else the page happens to do, this checks the
  # property that matters: reading the parameters no longer costs more per parameter.
  it 'does not read the parameters or requests more as parameters are added' do
    create(:parameter, request: first_request, name: 'only')
    with_one = definition_queries { state }

    4.times { |index| create(:parameter, request: first_request, name: "extra_#{index}") }
    with_five = definition_queries { state }

    expect(with_five.size).to eq with_one.size
  end

  # Only the queries against the two tables in question: a page load also queries the
  # session's user and the pipeline, and does so a different number of times on a second
  # request within one example.
  def definition_queries(&block)
    queries = []
    collect = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }

    ActiveSupport::Notifications.subscribed(collect, 'sql.active_record', &block)
    queries.grep(/FROM `(parameters|requests)`/)
  end
end
