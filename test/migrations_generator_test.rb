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

    assert_includes schema, "table.string :ip, limit: Configuration::IP_LIMIT"
    assert_includes schema, "table.string :user_agent, limit: Configuration::USER_AGENT_LIMIT"
    assert_includes schema, "def add_request_columns!"
    assert_includes generator, "add_ip_and_user_agent_to_recording_studio_views_view_logs.rb"
    assert_includes migration, "RecordingStudioViews::Schema.add_request_columns!"
    refute_includes RecordingStudioViews::VIEW_LOG_AGGREGATABLE.keys, :ip
    refute_includes RecordingStudioViews::VIEW_LOG_AGGREGATABLE.keys, :user_agent
  end
end
