# frozen_string_literal: true

module RecordingStudioViews
  class ViewLog < ActiveRecord::Base
    self.table_name = Storage::TABLE
  end
end
