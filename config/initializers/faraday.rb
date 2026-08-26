# frozen_string_literal: true

# Every Faraday connection in the app inherits these: the extraction connections built in
# HttpClient, the destination API connections in Api::Request, and the bare Faraday.get in
# DestinationsController. No gem depends on Faraday, so nothing outside this app is affected.
#
# Without an explicit request block each connection fell through to Net::HTTP's defaults, so
# the timeouts the app actually ran with were written down nowhere. Naming them here also
# makes them tunable in an incident without a deploy.
#
# The read timeout keeps Net::HTTP's own 60 seconds. It applies per read rather than to the
# whole response, so it bounds how long a destination may think before it starts answering,
# not how long a large download may take - lowering it would fail loads that currently
# succeed, and cutting short the time spent on a batch that is failing belongs with
# Retriable's configuration rather than here.
#
# The open timeout does not need 60 seconds by any reading. Every host the app talks to is
# either in the same cluster or on the public internet, and a TCP handshake that has not
# completed in five seconds is not going to.
user_agent = ENV.fetch('SJ_USER_AGENT', 'Supplejack Harvester v2.0')

Faraday.default_connection_options = {
  headers: { user_agent: },
  request: {
    open_timeout: ENV.fetch('HTTP_OPEN_TIMEOUT', 5).to_i,
    timeout: ENV.fetch('HTTP_READ_TIMEOUT', 60).to_i
  }
}
