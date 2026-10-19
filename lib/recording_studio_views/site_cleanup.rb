# frozen_string_literal: true

module RecordingStudioViews
  module SiteCleanup
    def self.call(before: Time.current.utc)
      ViewLog.where(root_recording_id: nil).where("occurred_at < ?", before).delete_all
    end
  end
end
