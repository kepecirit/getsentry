require "spec_helper"

RSpec.describe "Sentry::Breadcrumbs::ActiveSupportLogger", type: :request do
  before(:all) do
    make_basic_app do |sentry_config|
      sentry_config.breadcrumbs_logger = [:active_support_logger]
    end
  end

  after(:all) do
    require 'sentry/rails/breadcrumb/active_support_logger'
    Sentry::Rails::Breadcrumb::ActiveSupportLogger.detach
    # even though we cleanup breadcrumbs in the rack middleware
    # Breadcrumbs::ActiveSupportLogger subscribes to "every" instrumentation
    # so it'll create other instrumentations "after" the request is finished
    # and we should clear those as well
    Sentry.get_current_scope.clear_breadcrumbs
  end

  let(:transport) do
    Sentry.get_current_client.transport
  end

  let(:event) do
    transport.events.first.to_json_compatible
  end

  after do
    transport.events = []
  end

  it "captures correct data" do
    get "/exception"

    expect(response.status).to eq(500)
    breadcrumbs = event.dig("breadcrumbs", "values")
    expect(breadcrumbs.count).to eq(2)
    expect(breadcrumbs.first["data"]).to include(
      {
        "controller" => "HelloController",
        "action" => "exception",
        "params" => { "controller" => "hello", "action" => "exception" },
        "format" => "html",
        "method" => "GET", "path" => "/exception",
      }
    )
  end

  it "ignores exception data" do
    get "/view_exception"

    expect(event.dig("breadcrumbs", "values", -1, "data").keys).not_to include("exception")
    expect(event.dig("breadcrumbs", "values", -1, "data").keys).not_to include("exception_object")
  end

  it "ignores events that doesn't have a started timestamp" do
    expect do
      ActiveSupport::Notifications.publish "foo", Object.new
    end.not_to raise_error

    expect(transport.events).to be_empty
  end
end
