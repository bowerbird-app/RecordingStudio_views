# frozen_string_literal: true

require "test_helper"

class MigrationsGeneratorTest < Minitest::Test
  def test_schema_and_generator_add_request_columns
    schema = File.read(File.expand_path("../lib/recording_studio_views/schema.rb", __dir__))
    generator = File.read(
      File.expand_path("../lib/generators/recording_studio_views/migrations/migrations_generator.rb", __dir__)
    )
    migration = File.read(
      File.expand_path(
        "../db/migrate/20261020030500_add_ip_and_user_agent_to_recording_studio_views_view_logs.rb",
        __dir__
      )
    )

    assert_includes schema, "ip: Configuration::IP_LIMIT"
    assert_includes schema, "user_agent: Configuration::USER_AGENT_LIMIT"
    assert_includes schema, "browser: Configuration::DEVICE_FIELD_LIMIT"
    assert_includes schema, "os_version: Configuration::DEVICE_FIELD_LIMIT"
    assert_includes schema, "utm_source: Configuration::UTM_LIMIT"
    assert_includes schema, "country: Configuration::GEO_NAME_LIMIT"
    assert_includes schema, "request_string_columns.each { |name, limit| table.string name, limit: limit }"
    assert_includes schema, "table.decimal :latitude, precision: 10, scale: 6"
    assert_includes schema, "def add_request_columns!"
    assert_includes generator, "add_ip_and_user_agent_to_recording_studio_views_view_logs.rb"
    assert_includes migration, "RecordingStudioViews::Schema.add_request_columns!"
    %i[
      ip user_agent browser os os_version device_type
      utm_source utm_medium utm_term utm_content utm_campaign
      country region city latitude longitude
    ].each do |column|
      refute_includes RecordingStudioViews::VIEW_LOG_AGGREGATABLE.keys, column
    end
  end
end
