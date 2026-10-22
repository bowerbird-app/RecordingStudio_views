# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioViews::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(store_ip: false, token_ttl: 30.minutes, site_tracking_enabled: true)

    assert_equal false, @configuration.store_ip
    assert_equal 30.minutes, @configuration.token_ttl
    assert_equal true, @configuration.site_tracking_enabled
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", token_ttl: 7.minutes)

    refute_respond_to @configuration, :unknown_key
    assert_equal 7.minutes, @configuration.token_ttl
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:token_ttl], @configuration.token_ttl
    assert_equal original[:store_ip], @configuration.store_ip
    assert_equal original[:site_tracking_enabled], @configuration.site_tracking_enabled
  end

  def test_initialize_uses_defaults
    configuration = RecordingStudioViews::Configuration.new

    refute_respond_to configuration, :api_key
    refute_respond_to configuration, :enable_feature_x
    refute_respond_to configuration, :timeout
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
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("store_ip" => false, "token_ttl" => 12.minutes)

    assert_equal false, @configuration.store_ip
    assert_equal 12.minutes, @configuration.token_ttl
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
