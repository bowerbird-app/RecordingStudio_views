# frozen_string_literal: true

require "securerandom"

module RecordingStudioViews
  module PageViewPayload
    KEYS = %i[
      schema_version
      occurred_at
      path
      root_recording_id
      recording_id
      page_view_id
      user_id
      visitor_id
      referrer
      query_params
    ].freeze

    def self.build(view)
      KEYS.index_with { |key| value_for(view, key) }
    end

    def self.value_for(view, key)
      case key
      when :schema_version then PAYLOAD_SCHEMA_VERSION
      when :occurred_at then view.occurred_at&.iso8601
      when :page_view_id then view.id
      when :query_params then QueryParams.extract(view.query_params)
      else view.public_send(key)
      end
    end
    private_class_method :value_for
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
