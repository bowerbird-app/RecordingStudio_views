# frozen_string_literal: true

class CreateRecordingStudioViewsDailyViewSummaries < ActiveRecord::Migration[8.1]
  def up
    drop_table :recording_studio_views_page_view_summaries, if_exists: true
    RecordingStudioViews::Schema.create_summaries!(connection: connection)
  end

  def down
    drop_table RecordingStudioViews::Schema::SUMMARIES, if_exists: true
  end
end
