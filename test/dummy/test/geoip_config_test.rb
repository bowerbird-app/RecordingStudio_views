# frozen_string_literal: true

require "test_helper"

class GeoipConfigTest < ActiveSupport::TestCase
  test "test env does not set a geoip path without maxmind credentials" do
    [Rails.application.credentials.dig(:maxmind, :account_id),
     Rails.application.credentials.dig(:maxmind, :license_key)].each do |value|
      assert value.blank? || value == "dev_placeholder"
    end
    assert_nil RecordingStudioViews.configuration.geoip_database_path
    assert_nil RecordingStudioViews.configuration.maxmind_account_id
    assert_nil RecordingStudioViews.configuration.maxmind_license_key
  end

  test "dummy initializer only assigns geoip when maxmind credentials exist" do
    source = File.read(Rails.root.join("config/initializers/recording_studio_views.rb"))

    assert_includes source, 'config.geoip_database_path = Rails.root.join("db/GeoLite2-City.mmdb")'
    assert_includes source, "if real.(account_id) && real.(license_key)"
  end

  test "geoip update rake task is loaded" do
    Rails.application.load_tasks
    assert Rake::Task.task_defined?("recording_studio_views:geoip:update")
  end
end
