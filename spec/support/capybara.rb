# frozen_string_literal: true

require 'capybara/rails'
require 'capybara-screenshot/rspec'

# Chromedriver reports a node resolved against a document that has since been replaced as
# UnknownError rather than StaleElementReferenceError, and Capybara retries only the latter
# (Capybara::Selenium::Driver#invalid_element_errors). A click that navigates - a button_to
# inside a modal, say - can land the next query in that window: Document#text resolves the
# <html> node and then asks it for its text, and the new document can commit between the two.
# So it is treated as what it is, a stale node worth asking for again, rather than failing an
# example that a retry a moment later would pass.
#
# The cost is that a genuine UnknownError - a browser crash - takes until
# Capybara.default_max_wait_time to surface instead of failing at once. A slower failure,
# never a passing test.
Capybara::Selenium::Driver.prepend(Module.new do
  def invalid_element_errors
    super + [Selenium::WebDriver::Error::UnknownError]
  end
end)

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_chrome_headless
  end
end
