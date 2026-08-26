# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeletePreviousRecords::Execution do
  let(:destination)        { create(:destination) }

  before do
    stub_request(:post, "http://www.localhost:3000/harvester/records/flush").
      with(
        body: "{\"source_id\":\"source_id\",\"job_id\":\"job_id\"}",
        headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authentication-Token'=>'testkey',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Supplejack Harvester v2.0'
        }).
      to_return(status: 200, body: "", headers: {})
  end

  describe '#call' do
    it 'sends the source_id and the job_id to the API to trigger the deletion of previously harvested records' do
      expect(described_class.new('source_id', 'job_id', destination).call.status).to eq 200
    end

    # The flush is the slowest request made of the destination, so it is the likeliest to time
    # out - and both callers have work left to do after it. See the comment on #call.
    context 'when the destination does not answer' do
      before do
        stub_request(:post, 'http://www.localhost:3000/harvester/records/flush').to_timeout
      end

      it 'does not raise, so the caller can finish the run' do
        expect { described_class.new('source_id', 'job_id', destination).call }.not_to raise_error
      end

      it 'says which flush was lost' do
        allow(Rails.logger).to receive(:info)

        described_class.new('source_id', 'job_id', destination).call

        expect(Rails.logger).to have_received(:info).with(/flush of source_id for job job_id failed/)
      end
    end
  end
end
