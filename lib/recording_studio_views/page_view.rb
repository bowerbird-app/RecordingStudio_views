# frozen_string_literal: true

require "securerandom"

module RecordingStudioViews
  module PageViewPayload
    def self.build(view)
      {
        schema_version: PAYLOAD_SCHEMA_VERSION,
        occurred_at: view.occurred_at&.iso8601,
        path: view.path,
        root_recording_id: view.root_recording_id,
        user_id: view.user_id,
        visitor_id: view.visitor_id,
        referrer: view.referrer,
        query_params: QueryParams.extract(view.query_params)
      }
    end
  end

  # Partitioned page-view row. Column shape follows the Logs site_views
  # demonstration (resource_type, root_recording_id, recording_id, occurred_at)
  # plus the fields the recorded event publishes.
  class PageView < ActiveRecord::Base
    self.table_name = "recording_studio_views_page_views"
    self.primary_key = %i[id occurred_at]

    include RecordingStudioLogs::EnsuresPartition

    before_create :assign_id_when_blank
    after_commit :publish_recorded_event, on: :create

    def event_payload
      PageViewPayload.build(self)
    end

    private

    def assign_id_when_blank
      self.id = SecureRandom.uuid if id.blank?
    end

    def publish_recorded_event
      ActiveSupport::Notifications.instrument(PAGE_VIEW_RECORDED, event_payload)
    end
  end
end
