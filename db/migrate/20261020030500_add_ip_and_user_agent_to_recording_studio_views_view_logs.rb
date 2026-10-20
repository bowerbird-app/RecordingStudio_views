# frozen_string_literal: true

class AddIpAndUserAgentToRecordingStudioViewsViewLogs < ActiveRecord::Migration[8.1]
  def up
    RecordingStudioViews::Schema.add_request_columns!(connection: connection)
  end

  def down
    if column_exists?(:recording_studio_views_view_logs, :user_agent)
      remove_column :recording_studio_views_view_logs, :user_agent
    end
    return unless column_exists?(:recording_studio_views_view_logs, :ip)

    remove_column :recording_studio_views_view_logs, :ip
  end
end
