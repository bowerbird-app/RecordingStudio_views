# frozen_string_literal: true

require "test_helper"
require "securerandom"

class WriteViewTest < ActiveSupport::TestCase
  test "a failed insert rolls back the receipt so a retry can proceed" do
    context = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    event_id = SecureRandom.uuid
    original = RecordingStudioViews::ViewLog.method(:insert_all!)
    RecordingStudioViews::ViewLog.define_singleton_method(:insert_all!) do |*_args, **_kwargs|
      raise ActiveRecord::StatementInvalid, "disk full"
    end

    result = RecordingStudioViews::WriteView.call(
      event_id: event_id,
      context: context,
      path: "/site/about"
    )

    assert result.failure?
    assert_nil RecordingStudioViews::ViewReceipt.find_by(id: event_id)
  ensure
    RecordingStudioViews::ViewLog.define_singleton_method(:insert_all!) do |*args, **kwargs, &block|
      original.call(*args, **kwargs, &block)
    end
  end

  test "site cleanup deletes null-root rows only" do
    context = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    RecordingStudioViews::WriteView.call(
      event_id: SecureRandom.uuid,
      context: context,
      path: "/site/about"
    )
    RecordingStudioViews::SiteCleanup.call(before: Time.current.utc + 1.second)
    assert_equal 1, RecordingStudioViews::ViewLog.where(root_recording_id: nil).count

    RecordingStudioLogs.aggregate_day!(Time.now.utc.to_date)
    RecordingStudioViews::SiteCleanup.call(before: Time.current.utc + 1.second)
    assert_equal 0, RecordingStudioViews::ViewLog.where(root_recording_id: nil).count
  end

  test "write view masks ip truncates user agent and honors store_ip" do
    previous = RecordingStudioViews.configuration.store_ip
    context = RecordingStudioViews::PageContext.new(
      kind: :site,
      recording_id: nil,
      root_recording_id: nil,
      resource_type: "Site",
      page_key: "site.about",
      version: 1
    )
    stored = RecordingStudioViews::WriteView.call(
      event_id: SecureRandom.uuid,
      context: context,
      path: "/site/about",
      ip: "1.2.3.4",
      user_agent: "Z" * 2_000
    ).value[:view]
    assert_equal "1.2.3.0", stored.ip
    assert_equal RecordingStudioViews::Configuration::USER_AGENT_LIMIT, stored.user_agent.length

    RecordingStudioViews.configuration.store_ip = false
    skipped = RecordingStudioViews::WriteView.call(
      event_id: SecureRandom.uuid,
      context: context,
      path: "/site/about",
      ip: "9.8.7.6",
      user_agent: "Agent/2"
    ).value[:view]
    assert_nil skipped.ip
    assert_equal "Agent/2", skipped.user_agent
  ensure
    RecordingStudioViews.configuration.store_ip = previous
  end

  test "receipt cleanup expires old claims" do
    receipt = RecordingStudioViews::ViewReceipt.create!(
      id: SecureRandom.uuid,
      target_fingerprint: "abc",
      accepted_at: 48.hours.ago
    )
    RecordingStudioViews::ReceiptCleanupJob.perform_now
    assert_nil RecordingStudioViews::ViewReceipt.find_by(id: receipt.id)
  end
end
