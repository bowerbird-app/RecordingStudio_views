# frozen_string_literal: true

class AddIpAndUserAgentToRecordingStudioViewsViewLogs < ActiveRecord::Migration[8.1]
  def up
    RecordingStudioViews::Schema.add_request_columns!(connection: connection)
  end

  def down
    %i[
      longitude latitude city region country
      utm_campaign utm_content utm_term utm_medium utm_source
      os_version device_type os browser user_agent ip
    ].each do |column|
      next unless column_exists?(:recording_studio_views_view_logs, column)

      remove_column :recording_studio_views_view_logs, column
    end
  end
end
