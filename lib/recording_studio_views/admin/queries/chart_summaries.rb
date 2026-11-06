# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module ChartSummaries
        SUMMARY_FILTER_COLUMNS = %i[root_recording_id recording_id resource_type page_key].freeze

        def daily_view_counts(relation, range_start: nil, range_end: nil, filters: {}, actor: nil,
                              access_recording: nil)
          filters = normalize_chart_filters(filters, actor: actor, access_recording: access_recording)
          relation = apply_chart_filters_to_logs(chart_relation(relation), filters)
          return raw_views_by_day_utc(relation) if summary_incompatible?(filters)

          counts = summary_views_by_day(
            filters, range_start, range_end, actor: actor, access_recording: access_recording
          )
          raw_views_by_day_utc(
            unsummarized_view_logs(relation, actor: actor, access_recording: access_recording)
          ).each do |day, count|
            counts[day] = counts[day].to_i + count.to_i
          end
          counts
        end

        def summary_incompatible?(filters)
          filters.key?(:visit_kind) || filters.key?(:path)
        end

        def summarized_utc_days(actor: nil, access_recording: nil)
          scoped_summaries(actor: actor, access_recording: access_recording)
            .distinct.pluck(:day).filter_map { |day| coerce_utc_date(day) }
        end

        def unsummarized_view_logs(relation = ViewLog.all, summarized_days = nil, actor: nil,
                                   access_recording: nil)
          summarized_days ||= summarized_utc_days(actor: actor, access_recording: access_recording)
          relation = chart_relation(relation)
          return relation if summarized_days.empty?

          quoted_days = summarized_days.map { |day| ViewLog.connection.quote(day) }.join(", ")
          relation.where("((#{quoted_occurred_at} AT TIME ZONE 'UTC')::date) NOT IN (#{quoted_days})")
        end

        private

        def raw_views_by_day_utc(relation)
          day_sql = "(#{quoted_occurred_at} AT TIME ZONE 'UTC')::date"
          grouped = chart_relation(relation).group(Arel.sql(day_sql)).count
          grouped.each_with_object({}) do |(value, count), memo|
            date = coerce_utc_date(value)
            memo[date] = memo[date].to_i + count.to_i if date
          end
        end

        def summary_views_by_day(filters, range_start, range_end, actor: nil, access_recording: nil)
          scope = scoped_summaries(actor: actor, access_recording: access_recording)
          scope = scope.where(day: range_start..range_end) if range_start && range_end
          apply_summary_filters(scope, filters).group(:day).sum(:views).each_with_object({}) do |(day, views), memo|
            date = coerce_utc_date(day)
            memo[date] = memo[date].to_i + views.to_i if date
          end
        end

        def apply_summary_filters(scope, filters)
          SUMMARY_FILTER_COLUMNS.each do |column|
            scope = scope.where(column => filters[column]) if filters.key?(column)
          end
          return scope unless filters.key?(:page_key_contains)

          contains_match(scope, :page_key, filters[:page_key_contains])
        end
      end
    end
  end
end
