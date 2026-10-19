# frozen_string_literal: true

class CreateRecordingStudioViewsViewLogs < ActiveRecord::Migration[8.1]
  def up
    drop_table :recording_studio_views_page_views, if_exists: true, force: :cascade
    RecordingStudioViews::Schema.create_view_logs!(partitioned: false, connection: connection)
  end

  def down
    drop_table RecordingStudioViews::Schema::VIEW_LOGS, if_exists: true, force: :cascade
  end
end
