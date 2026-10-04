ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # The FormGuard fields a real browser sends: form rendered a while ago,
  # JavaScript ran, honeypot left empty.
  def human_form(rendered: 10.seconds.ago)
    { fg_ts: Rails.application.message_verifier(:form_guard).generate(rendered.to_i), fg_js: "1", subject_line: "" }
  end
end
