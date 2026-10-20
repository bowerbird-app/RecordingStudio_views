# frozen_string_literal: true

require "test_helper"

class GeoLookupTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/GeoIP2-City-Test.mmdb", __dir__)
  CITY_IP = "81.2.69.142"

  def setup
    @previous_path = RecordingStudioViews.configuration.geoip_database_path
    RecordingStudioViews::GeoLookup.reset!
  end

  def teardown
    RecordingStudioViews.configuration.geoip_database_path = @previous_path
    RecordingStudioViews::GeoLookup.reset!
  end

  def test_geo_off_without_path_is_nil
    RecordingStudioViews.configuration.geoip_database_path = nil

    refute RecordingStudioViews.configuration.geo_enabled
    result = RecordingStudioViews::GeoLookup.call(CITY_IP)
    assert_nil result[:country]
    assert_nil result[:region]
    assert_nil result[:city]
    assert_nil result[:latitude]
    assert_nil result[:longitude]
  end

  def test_local_city_fixture_lookup
    RecordingStudioViews.configuration.geoip_database_path = FIXTURE

    assert RecordingStudioViews.configuration.geo_enabled
    result = RecordingStudioViews::GeoLookup.call(CITY_IP)
    assert_equal "United Kingdom", result[:country]
    assert_equal "England", result[:region]
    assert_equal "London", result[:city]
    assert_in_delta 51.5142, result[:latitude], 0.0001
    assert_in_delta(-0.0931, result[:longitude], 0.0001)
  end

  def test_missing_file_does_not_raise
    RecordingStudioViews.configuration.geoip_database_path = "/tmp/does-not-exist-geoip2.mmdb"

    result = RecordingStudioViews::GeoLookup.call(CITY_IP)
    assert_nil result[:country]
  end
end
