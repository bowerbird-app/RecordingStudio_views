# frozen_string_literal: true

class CreateRecordingStudioViewsPageViewSummaries < ActiveRecord::Migration[8.1]
  TABLE = :recording_studio_views_page_view_summaries

  def up
    create_table TABLE, id: :uuid do |table|
      summary_columns(table)
    end
    add_identity_index
  end

  def down
    drop_table TABLE, if_exists: true
  end

  private

  def summary_columns(table)
    table.date :day, null: false
    table.uuid :root_recording_id
    table.string :resource_type, null: false
    table.integer :views, null: false, default: 0
    table.timestamps
  end

  def add_identity_index
    RecordingStudioLogs::Schema.summary_index(
      TABLE,
      %i[day root_recording_id resource_type],
      name: "index_rs_views_page_view_summaries_identity",
      connection: connection
    )
  end
end
