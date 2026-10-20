# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioViews::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(api_key: "abc123", timeout: 9, enable_feature_x: true)

    assert_equal "abc123", @configuration.api_key
    assert_equal 9, @configuration.timeout
    assert_equal true, @configuration.enable_feature_x
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", timeout: 7)

    refute_respond_to @configuration, :unknown_key
    assert_equal 7, @configuration.timeout
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_nil @configuration.api_key if original[:api_key].nil?
    assert_equal original[:api_key], @configuration.api_key unless original[:api_key].nil?
    assert_equal original[:timeout], @configuration.timeout
    assert_equal original[:enable_feature_x], @configuration.enable_feature_x
  end

  def test_initialize_uses_environment_api_key_and_defaults
    previous_value = ENV.fetch("RECORDING_STUDIO_VIEWS_API_KEY", nil)
    ENV["RECORDING_STUDIO_VIEWS_API_KEY"] = "env-token"

    configuration = RecordingStudioViews::Configuration.new

    assert_equal "env-token", configuration.api_key
    assert_equal false, configuration.enable_feature_x
    assert_equal 5, configuration.timeout
    assert_equal 2.hours, configuration.token_ttl
    assert_equal RecordingStudioViews::Configuration::DEFAULT_TOKEN_TTL, configuration.token_ttl
    assert_equal true, configuration.rate_limiting_enabled
    assert_nil configuration.rate_limit_store
    assert_equal 120, configuration.visitor_rate_limit
    assert_equal 30, configuration.visitor_root_rate_limit
    assert_equal 1.minute, configuration.rate_limit_window
    assert_equal true, configuration.store_ip
    assert_nil configuration.geoip_database_path
    assert_nil configuration.maxmind_account_id
    assert_nil configuration.maxmind_license_key
    assert_equal 7.days, configuration.geoip_max_age
    assert_equal false, configuration.geo_enabled
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  ensure
    ENV["RECORDING_STUDIO_VIEWS_API_KEY"] = previous_value
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("api_key" => "string-key", "timeout" => 12)

    assert_equal "string-key", @configuration.api_key
    assert_equal 12, @configuration.timeout
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioViews.configure

    assert_kind_of RecordingStudioViews::Configuration, RecordingStudioViews.configuration
  end
end
