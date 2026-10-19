# frozen_string_literal: true

class CreateRecordingStudioViewsViewReceipts < ActiveRecord::Migration[8.1]
  def up
    RecordingStudioViews::Schema.create_receipts!(connection: connection)
  end

  def down
    drop_table RecordingStudioViews::Schema::RECEIPTS, if_exists: true
  end
end
