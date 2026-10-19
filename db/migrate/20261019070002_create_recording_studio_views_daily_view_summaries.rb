# frozen_string_literal: true

class CreateRecordingStudioViewsDailyViewSummaries < ActiveRecord::Migration[8.1]
  def up
    RecordingStudioViews::Schema.create_summaries!(connection: connection)
  end

  def down
    drop_table RecordingStudioViews::Schema::SUMMARIES, if_exists: true
  end
end
