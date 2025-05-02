require 'rails_helper'

RSpec.describe ApplicationWorker do
  let(:test_worker) { Class.new(ApplicationWorker) }

  before do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  describe '.perform_async_with_priority' do
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

  describe '.perform_in_with_priority' do
    context 'when priority is present' do
      it 'performs in with the specified queue' do
        test_worker.perform_in_with_priority('high_priority', 5.seconds, 123)
        expect(test_worker.jobs.size).to eq(1)
        expect(test_worker.jobs.first['args']).to eq([123])
        expect(test_worker.jobs.first['queue']).to eq('high_priority')
        expect(test_worker.jobs.first['at']).to be_within(1).of(5.seconds.from_now.to_f)
      end
    end

    context 'when priority is blank' do
      it 'performs in without setting queue' do
        test_worker.perform_in_with_priority(nil, 5.seconds, 123)
        expect(test_worker.jobs.size).to eq(1)
        expect(test_worker.jobs.first['args']).to eq([123])
        expect(test_worker.jobs.first['queue']).to eq('default')
        expect(test_worker.jobs.first['at']).to be_within(1).of(5.seconds.from_now.to_f)
      end
    end
  end
end