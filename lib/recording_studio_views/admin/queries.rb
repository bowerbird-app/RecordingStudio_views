# frozen_string_literal: true

require_relative "queries/actor_labels"
require_relative "queries/chart_series"
require_relative "queries/filters"

module RecordingStudioViews
  module Admin
    module Queries
      PUBLIC = "Public"
      PRIVATE = "Private"
      SIGNED_IN = "Signed in"
      SITE_ROOT_LABEL = "Site"
      ANONYMOUS_ACTOR = "Anonymous"

      class << self
        include ActorLabels
        include ChartSeries
        include Filters

        def view_logs
          ViewLog.order(occurred_at: :desc)
        end

        def total_views
          summary_total = DailyViewSummary.sum(:views).to_i
          days = DailyViewSummary.distinct.pluck(:day)
          raw_total = if days.empty?
                        ViewLog.count
                      else
                        quoted_days = days.map { |day| ViewLog.connection.quote(day) }.join(", ")
                        ViewLog.where(
                          "((#{quoted_occurred_at} AT TIME ZONE 'UTC')::date) NOT IN (#{quoted_days})"
                        ).count
                      end
          summary_total + raw_total
        end

        def page_views_over_time_series(day_range: default_day_range)
          counts = views_by_day_utc(day_range)
          data = day_range.map { |day| { x: day, y: counts[day].to_i } }
          [{ name: "Page views", data: data }]
        end

        def views_by_day_utc(day_range)
          DailyViewSummary.where(day: day_range).group(:day).sum(:views)
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

        def occurred_at_value(row, _context)
          row.occurred_at&.utc
        end

        def root_value(row, _context)
          root_label(row.root_recording_id)
        end

        def page_key_value(row, _context)
          row.page_key
        end

        def resource_type_value(row, _context)
          row.resource_type
        end

        def path_value(row, _context)
          row.path
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
