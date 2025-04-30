require 'rails_helper'

RSpec.describe ApplicationWorker do
  describe '.perform_async_with_priority' do
    let(:test_worker) { Class.new(ApplicationWorker) }

    before do
      Sidekiq::Testing.fake!
      Sidekiq::Worker.clear_all
    end

    context 'when priority is present' do
      it 'performs async with the specified queue' do
        test_worker.perform_async_with_priority('high_priority', 123)
        expect(test_worker.jobs.size).to eq(1)
        expect(test_worker.jobs.first['args']).to eq([123])
        expect(test_worker.jobs.first['queue']).to eq('high_priority')
      end
    end

    context 'when priority is blank' do
      it 'performs async without setting queue' do
        test_worker.perform_async_with_priority(nil, 123)
        expect(test_worker.jobs.size).to eq(1)
        expect(test_worker.jobs.first['args']).to eq([123])
        expect(test_worker.jobs.first['queue']).to eq('default')
      end
    end
  end
end