# frozen_string_literal: true

require_relative "queries/actor_labels"
require_relative "queries/chart_series"
require_relative "queries/chart_summaries"
require_relative "queries/filters"
require_relative "queries/row_values"

module RecordingStudioViews
  module Admin
    module Queries
      SIGNED_IN = "Signed in"
      SITE_ROOT_LABEL = "Site"
      ANONYMOUS_ACTOR = "Anonymous"

      class << self
        include ActorLabels
        include ChartSeries
        include ChartSummaries
        include Filters
        include RowValues

        def view_logs
          ViewLog.order(occurred_at: :desc)
        end

        def total_views
          DailyViewSummary.sum(:views).to_i + unsummarized_view_logs.count
        end

        def page_views_over_time_series(day_range: default_day_range)
          counts = views_by_day_utc(day_range)
          data = day_range.map { |day| { x: day, y: counts[day].to_i } }
          [{ name: "Page views", data: data }]
        end

        def views_by_day_utc(day_range)
          day_sql = "(#{quoted_occurred_at} AT TIME ZONE 'UTC')::date"
          relation = ViewLog.where("#{day_sql} BETWEEN ? AND ?", day_range.begin, day_range.end)
          views_by_bucket_utc(relation, :day, range_start: day_range.begin, range_end: day_range.end)
        end

        def default_day_range
          today = Time.now.utc.to_date
          (today - 29)..today
        end

        def root_filter_options
          ids = ViewLog.distinct.pluck(:root_recording_id)
          labels = ids.map { |id| root_label(id) }
          labels.uniq.sort
        end

        def resource_type_filter_options
          ViewLog.where.not(resource_type: [nil, ""]).distinct.order(:resource_type).pluck(:resource_type)
        end

        def root_label(root_recording_id)
          return SITE_ROOT_LABEL if root_recording_id.blank?

          recording = RecordingStudio::Recording.find_by(id: root_recording_id)
          recordable = recording&.recordable
          name = recordable&.try(:name) || recordable&.try(:title)
          name.presence || root_recording_id.to_s
        end

        def root_id_for_label(label)
          ViewLog.distinct.pluck(:root_recording_id).compact.find do |id|
            root_label(id) == label
          end
        end
      end
    end
  end
end
