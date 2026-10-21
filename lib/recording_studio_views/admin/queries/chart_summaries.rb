# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module ChartSummaries
        SUMMARY_FILTER_COLUMNS = %w[root_recording_id recording_id resource_type page_key].freeze
        SUMMARY_COMPATIBLE_COLUMNS = (SUMMARY_FILTER_COLUMNS + %w[occurred_at]).freeze

        def daily_view_counts(relation, range_start: nil, range_end: nil)
          relation = chart_relation(relation)
          return raw_views_by_day_utc(relation) if summary_incompatible?(relation)

          counts = summary_views_by_day(relation, range_start, range_end)
          raw_views_by_day_utc(unsummarized_view_logs(relation)).each do |day, count|
            counts[day] = counts[day].to_i + count.to_i
          end
          counts
        end

        def summary_incompatible?(relation)
          filtered_where_columns(relation).any? do |column|
            SUMMARY_COMPATIBLE_COLUMNS.exclude?(column)
          end
        end

        def summarized_utc_days
          DailyViewSummary.distinct.pluck(:day).filter_map { |day| coerce_utc_date(day) }
        end

        def unsummarized_view_logs(relation = ViewLog.all, summarized_days = summarized_utc_days)
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

        def summary_views_by_day(relation, range_start, range_end)
          scope = DailyViewSummary.all
          scope = scope.where(day: range_start..range_end) if range_start && range_end
          apply_summary_filters(scope, relation).group(:day).sum(:views).each_with_object({}) do |(day, views), memo|
            date = coerce_utc_date(day)
            memo[date] = memo[date].to_i + views.to_i if date
          end
        end

        def apply_summary_filters(scope, relation)
          hash = relation.where_values_hash
          SUMMARY_FILTER_COLUMNS.each do |column|
            scope = scope.where(column => hash[column]) if hash.key?(column)
          end
          return scope if hash.key?("page_key")

          pattern = contains_bind_pattern(relation)
          return scope unless pattern

          quoted = DailyViewSummary.connection.quote_column_name("page_key")
          scope.where("#{quoted} ILIKE ?", pattern)
        end

        def contains_bind_pattern(relation)
          relation.where_clause.binds.map { |bind| bind_database_value(bind) }.find do |value|
            value.is_a?(String) && value.start_with?("%") && value.end_with?("%")
          end
        end

        def bind_database_value(bind)
          return bind.value_for_database if bind.respond_to?(:value_for_database)
          return bind.value if bind.respond_to?(:value)

          bind
        end

        def filtered_where_columns(relation)
          fragment = where_fragment(relation)
          return [] if fragment.empty?

          ViewLog.column_names.select do |column|
            quoted = ViewLog.connection.quote_column_name(column)
            fragment.include?(quoted) || fragment.match?(/\b#{Regexp.escape(column)}\b/)
          end
        end

        def where_fragment(relation)
          sql = chart_relation(relation).to_sql
          match = sql.match(/ where /i)
          match ? sql[match.begin(0)..] : ""
        end
      end
    end
  end
end
