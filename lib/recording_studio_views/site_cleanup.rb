# frozen_string_literal: true

module RecordingStudioViews
  module SiteCleanup
    def self.call(before: Time.current.utc)
      days = aggregated_site_days
      return 0 if days.empty?

      quoted_days = days.map { |day| ViewLog.connection.quote(day) }.join(", ")
      ViewLog.where(root_recording_id: nil)
             .where("occurred_at < ?", before)
             .where("((occurred_at AT TIME ZONE 'UTC')::date) IN (#{quoted_days})")
             .delete_all
    end

    def self.aggregated_site_days
      DailyViewSummary.where(root_recording_id: nil).distinct.pluck(:day)
    end
    private_class_method :aggregated_site_days
  end
end
