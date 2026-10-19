# frozen_string_literal: true

class CreateRecordingStudioViewsPageViews < ActiveRecord::Migration[8.1]
  TABLE = :recording_studio_views_page_views

  def up
    RecordingStudioLogs::Schema.partitioned_log(
      TABLE, timestamp_column: :occurred_at, connection: connection
    ) do |table|
      page_view_columns(table)
    end
    add_root_time_index
  end

  def down
    drop_table TABLE, if_exists: true, force: :cascade
  end

  private

  def page_view_columns(table)
    table.string :resource_type, null: false
    table.uuid :root_recording_id
    table.uuid :recording_id
    table.string :path, null: false
    table.uuid :user_id
    table.string :visitor_id
    table.text :referrer
    table.jsonb :query_params, null: false, default: {}
  end

  def add_root_time_index
    RecordingStudioLogs::Schema.root_and_time_index(
      TABLE, root_column: :root_recording_id, timestamp_column: :occurred_at, connection: connection
    )
  end
end
