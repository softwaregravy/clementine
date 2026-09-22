# The suite never reaches the network. Open Data reads are developed against the
# committed pulls in spec/fixtures/open_data, and Twilio is stubbed — no live API
# call and no real send ever originates from a test run (P8, P11).
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: false)
