# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module ChartSeries
        CHART_BUCKETS = %i[day week month].freeze

        def screen_page_views_series(relation, bucket: :day, start_date: nil, end_date: nil)
          bucket = normalize_chart_bucket(bucket)
          range_start = start_date.presence || default_day_range.begin
          range_end = end_date.presence || default_day_range.end
          counts = views_by_bucket_utc(relation, bucket, range_start: range_start, range_end: range_end)
          data = each_bucket_start(range_start, range_end, bucket).map do |start|
            { x: start, y: counts[start].to_i }
          end
          [{ name: "Page views", data: data }]
        end

        def normalize_chart_bucket(bucket)
          key = bucket.to_s.downcase.to_sym
          CHART_BUCKETS.include?(key) ? key : :day
        end

        def views_by_bucket_utc(relation, bucket, range_start: nil, range_end: nil)
          daily = daily_view_counts(relation, range_start: range_start, range_end: range_end)
          bucketed_daily_counts(daily, bucket)
        end

        def chart_relation(relation)
          relation.respond_to?(:except) ? relation.except(:order) : relation
        end

        def quoted_occurred_at
          ViewLog.connection.quote_column_name("occurred_at")
        end

        def each_bucket_start(range_start, range_end, bucket)
          cursor = bucket_start(range_start, bucket)
          last = bucket_start(range_end, bucket)
          starts = []
          while cursor && last && cursor <= last
            starts << cursor
            cursor = advance_bucket(cursor, bucket)
          end
          starts
        end

        def bucket_start(value, bucket)
          date = coerce_utc_date(value)
          return unless date

          case bucket
          when :week then date.beginning_of_week
          when :month then date.beginning_of_month
          else date
          end
        end

        def advance_bucket(date, bucket)
          case bucket
          when :week then date + 7
          when :month then date.next_month.beginning_of_month
          else date + 1
          end
        end

        def coerce_utc_date(value)
          return value.to_date if value.respond_to?(:to_date)

          Time.parse(value.to_s).utc.to_date
        rescue ArgumentError, TypeError
          nil
        end

        private

        def bucketed_daily_counts(daily, bucket)
          daily.each_with_object({}) do |(day, count), memo|
            start = bucket_start(day, bucket)
            memo[start] = memo[start].to_i + count.to_i if start
          end
        end
      end
    end
  end
end
