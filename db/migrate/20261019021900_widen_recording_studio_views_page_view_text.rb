# frozen_string_literal: true

class WidenRecordingStudioViewsPageViewText < ActiveRecord::Migration[8.1]
  def change
    change_column :recording_studio_views_page_views, :path, :text, null: false
    change_column :recording_studio_views_page_views, :visitor_id, :text
  end
end
