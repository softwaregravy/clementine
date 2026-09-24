require "rails_helper"
require "net/http"

# The skeleton promises two things, and this is where they are asserted: the
# application boots, and a test run cannot reach the network (P8, P11).
RSpec.describe "The Clementine skeleton" do
  it "boots the application" do
    expect(Rails.application).to be_initialized
  end

  it "runs in the test environment" do
    expect(Rails.env).to eq "test"
  end

  it "refuses a real request to the Open Data endpoint" do
    expect { Net::HTTP.get(URI("https://data.cityofnewyork.us/resource/nc67-uf89.json")) }
      .to raise_error(WebMock::NetConnectNotAllowedError)
  end
end
