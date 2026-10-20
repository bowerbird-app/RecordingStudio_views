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
    assert_includes source, "querySelectorAll(CONTEXT_SELECTOR)"
    assert_includes source, "awaitingVisible"
    assert_includes source, "postView(id, attempt + 1, payload)"
    refute_includes source, "navigator.sendBeacon"
    refute_includes source, "unload"
  end

  def test_collector_runtime_posts_current_token_hidden_tab_and_retry_context
    script = File.expand_path("collector_runtime_test.js", __dir__)
    output = IO.popen(["node", script], err: %i[child out], &:read)
    assert Process.last_status.success?, output
    assert_includes output, "collector runtime assertions passed"
  end
end
