# frozen_string_literal: true

class AddKindToRecordingStudioViewsViewLogs < ActiveRecord::Migration[8.1]
  def up
    RecordingStudioViews::Schema.add_kind_column!(connection: connection)
  end

  def down
    return unless column_exists?(:recording_studio_views_view_logs, :kind)

    remove_column :recording_studio_views_view_logs, :kind
  end
end
