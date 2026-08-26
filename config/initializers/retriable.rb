# frozen_string_literal: true

Retriable.configure do |c|
  c.tries = ENV.fetch('RETRIABLE_TRIES', 10).to_i
  c.base_interval = ENV.fetch('RETRIABLE_BASE_INTERVAL', 2).to_i
  c.multiplier = ENV.fetch('RETRIABLE_MULTIPLIER', 2).to_i

  # The load stage is not as patient as the rest of the app.
  #
  # The configuration above is shared by every Retriable.retriable call, and most of them wrap
  # an extraction, where ten patient tries against a flaky content source is the right answer:
  # a page that is not fetched is a page whose records are lost. A load has somewhere to put a
  # failure now - LoadWorker requeues the batch and tries again minutes later - so holding a
  # Sidekiq worker while the same request is made ten more times buys nothing and starves the
  # queue behind it.
  #
  # max_interval and max_elapsed_time were never set, so they came from the gem as 60 and 900,
  # and that arithmetic is what made this worth separating: an attempt that ends on the 60
  # second read timeout, ten of them, with backoff in between, is the full fifteen minutes on
  # one worker before the batch is given up on. Three tries against that same timeout is a
  # little over three minutes, and a destination refusing connections fails all three in a few
  # seconds. max_elapsed_time is left as a backstop for a read timeout raised through ENV,
  # rather than as the limit that normally applies.
  c.contexts[:load] = {
    tries: ENV.fetch('RETRIABLE_LOAD_TRIES', 3).to_i,
    base_interval: 1,
    multiplier: 2,
    max_interval: 5,
    max_elapsed_time: ENV.fetch('RETRIABLE_LOAD_MAX_ELAPSED_TIME', 200).to_i
  }
end
