# frozen_string_literal: true

require "test_helper"
require "securerandom"

class PartitionedViewLogTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
    @previous_interval = RecordingStudioLogs.logs.find { |log| log.model_name.include?("ViewLog") }&.partition_interval
    rebuild_table(partitioned: true)
  end

  teardown do
    rebuild_table(partitioned: false)
  end

  test "a missing month uses the logs insert path and a failed insert leaves no receipt" do
    inspection = RecordingStudioLogs::Schema.inspect_table("recording_studio_views_view_logs")
    assert inspection.partitioned
    RecordingStudioViews.register_view_log!
    log = RecordingStudioLogs.logs.find { |item| item.model_name == "RecordingStudioViews::ViewLog" }
    assert_equal :monthly, log.partition_interval

    context = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    event_id = SecureRandom.uuid
    travel_to Time.utc(2031, 3, 15, 12) do
      result = RecordingStudioViews::WriteView.call(
        event_id: event_id,
        context: context,
        path: "/site/about"
      )
      assert result.success?, result.error.to_s
    end
    assert RecordingStudioViews::ViewLog.where(id: event_id).exists?

    failed_id = SecureRandom.uuid
    original = RecordingStudioViews::ViewLog.method(:insert_all!)
    RecordingStudioViews::ViewLog.define_singleton_method(:insert_all!) do |*_args, **_kwargs|
      raise ActiveRecord::StatementInvalid, "partition missing"
    end
    begin
      result = RecordingStudioViews::WriteView.call(
        event_id: failed_id,
        context: context,
        path: "/site/about"
      )
      assert result.failure?
      assert_nil RecordingStudioViews::ViewReceipt.find_by(id: failed_id)
    ensure
      RecordingStudioViews::ViewLog.define_singleton_method(:insert_all!) do |*args, **kwargs, &block|
        original.call(*args, **kwargs, &block)
      end
    end
  end

  private

  def rebuild_table(partitioned:)
    @connection.drop_table :recording_studio_views_view_logs, if_exists: true, force: :cascade
    RecordingStudioViews::Schema.create_view_logs!(partitioned: partitioned, connection: @connection)
    RecordingStudioViews::ViewLog.reset_column_information
    RecordingStudioViews::Storage.apply!(RecordingStudioViews::ViewLog)
    RecordingStudioViews.register_view_log!
  end
end
