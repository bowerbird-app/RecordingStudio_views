# frozen_string_literal: true

require "test_helper"

class CollectorJavascriptTest < Minitest::Test
  def test_collector_binds_supported_navigation_and_ignores_the_rest
    source = File.read(
      File.expand_path("../app/assets/javascripts/recording_studio_views/collector.js", __dir__)
    )

    assert_includes source, 'document.addEventListener("turbo:load"'
    assert_includes source, 'document.addEventListener("DOMContentLoaded"'
    assert_includes source, 'window.addEventListener("pageshow"'
    assert_includes source, "crypto.randomUUID"
    assert_includes source, 'credentials: "same-origin"'
    assert_includes source, "X-CSRF-Token"
    assert_includes source, "data-turbo-preview"
    assert_includes source, 'window.addEventListener("hashchange"'
    assert_includes source, 'document.addEventListener("visibilitychange"'
    refute_includes source, "navigator.sendBeacon"
    refute_includes source, "unload"
  end
end
