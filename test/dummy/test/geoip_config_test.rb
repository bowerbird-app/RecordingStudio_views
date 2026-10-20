# frozen_string_literal: true

require "test_helper"

class GeoipConfigTest < ActiveSupport::TestCase
  test "test env does not set a geoip path without maxmind credentials" do
    refute Rails.application.credentials.dig(:maxmind, :account_id).present?
    refute Rails.application.credentials.dig(:maxmind, :license_key).present?
    assert_nil RecordingStudioViews.configuration.geoip_database_path
    assert_nil RecordingStudioViews.configuration.maxmind_account_id
    assert_nil RecordingStudioViews.configuration.maxmind_license_key
  end

  test "dummy initializer only assigns geoip when maxmind credentials exist" do
    source = File.read(Rails.root.join("config/initializers/recording_studio_views.rb"))

    assert_includes source, 'config.geoip_database_path = Rails.root.join("db/GeoLite2-City.mmdb")'
    assert_includes source, "if account_id.present? && license_key.present?"
  end

  test "geoip update rake task is loaded" do
    Rails.application.load_tasks
    assert Rake::Task.task_defined?("recording_studio_views:geoip:update")
  end
end
