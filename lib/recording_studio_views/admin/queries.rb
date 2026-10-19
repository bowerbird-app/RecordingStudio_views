# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      PUBLIC = "Public"
      PRIVATE = "Private"
      SIGNED_IN = "Signed in"
      SITE_ROOT_LABEL = "Site"
      ANONYMOUS_ACTOR = "Anonymous"
      CHART_BUCKETS = %i[day week month].freeze

      module_function

      def view_logs
        ViewLog.order(occurred_at: :desc)
      end

      def total_views
        ViewLog.count
      end

      def page_views_over_time_series(day_range: default_day_range)
        counts = views_by_day_utc(day_range)
        data = day_range.map { |day| { x: day, y: counts[day].to_i } }
        [{ name: "Page views", data: data }]
      end

      def screen_page_views_series(relation, bucket: :day, start_date: nil, end_date: nil)
        bucket = normalize_chart_bucket(bucket)
        range_start = start_date.presence || default_day_range.begin
        range_end = end_date.presence || default_day_range.end
        counts = views_by_bucket_utc(relation, bucket)
        data = each_bucket_start(range_start, range_end, bucket).map do |start|
          { x: start, y: counts[start].to_i }
        end
        [{ name: "Page views", data: data }]
      end

      def views_by_day_utc(day_range)
        DailyViewSummary.where(day: day_range).group(:day).sum(:views)
      end

      def default_day_range
        today = Time.now.utc.to_date
        (today - 29)..today
      end

      def filter_by_root(relation, value)
        label = value.to_s.strip
        return relation if label.empty?

        if label == SITE_ROOT_LABEL
          relation.where(root_recording_id: nil)
        else
          relation.where(root_recording_id: root_id_for_label(label))
        end
      end

      def filter_by_resource_type(relation, value)
        type = value.to_s.strip
        type.empty? ? relation : relation.where(resource_type: type)
      end

      def filter_by_page_key(relation, value)
        contains_match(relation, :page_key, value)
      end

      def filter_by_path(relation, value)
        contains_match(relation, :path, value)
      end

      def filter_by_visibility(relation, value)
        filter_by_visit_kind(relation, visibility_to_visit_kind(value))
      end

      def filter_by_visit_kind(relation, value)
        case value.to_s
        when ANONYMOUS_ACTOR
          relation.where(actor_id: [nil, ""])
        when SIGNED_IN, PRIVATE
          relation.where.not(actor_id: [nil, ""])
        else
          relation
        end
      end

      def visit_kind_filter_options
        [SIGNED_IN, ANONYMOUS_ACTOR]
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

      def actor_value(row, context = nil)
        return ANONYMOUS_ACTOR if row.actor_id.blank?

        cache = actor_label_cache(context)
        preload_actor_labels(cache, actor_rows_for_page(context, row))
        cache[actor_cache_key(row)] || fallback_actor_label(row)
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

      def contains_match(relation, column, value)
        needle = value.to_s.strip
        return relation if needle.empty?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(needle)}%"
        relation.where("#{ViewLog.connection.quote_column_name(column.to_s)} ILIKE ?", pattern)
      end

      def visibility_to_visit_kind(value)
        case value.to_s
        when PUBLIC then ANONYMOUS_ACTOR
        when PRIVATE then SIGNED_IN
        else value
        end
      end

      def normalize_chart_bucket(bucket)
        key = bucket.to_s.downcase.to_sym
        CHART_BUCKETS.include?(key) ? key : :day
      end

      def views_by_bucket_utc(relation, bucket)
        expression = bucket_group_expression(bucket)
        grouped = chart_relation(relation).group(Arel.sql(expression)).count
        grouped.each_with_object({}) do |(value, count), memo|
          start = bucket_start(value, bucket)
          memo[start] = memo[start].to_i + count.to_i if start
        end
      end

      def chart_relation(relation)
        relation.respond_to?(:except) ? relation.except(:order) : relation
      end

      def bucket_group_expression(bucket)
        field = "#{quoted_table}.#{quoted_occurred_at} AT TIME ZONE 'UTC'"
        case bucket
        when :week
          "DATE_TRUNC('week', #{field})"
        when :month
          "DATE_TRUNC('month', #{field})"
        else
          "DATE(#{field})"
        end
      end

      def quoted_table
        ViewLog.connection.quote_table_name(ViewLog.table_name)
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

      def actor_rows_for_page(context, row)
        rows = context&.table_result&.rows
        Array(rows.presence || [row])
      end

      def actor_label_cache(context)
        return {} unless context

        context.instance_variable_get(:@_recording_studio_views_actor_labels) ||
          context.instance_variable_set(:@_recording_studio_views_actor_labels, {})
      end

      def preload_actor_labels(cache, rows)
        pending = Array(rows).select { |row| row.actor_id.present? && !cache.key?(actor_cache_key(row)) }
        pending.group_by { |row| row.actor_type.to_s }.each do |type, typed_rows|
          next if type.blank?

          klass = type.safe_constantize
          ids = typed_rows.map { |row| row.actor_id.to_s }.uniq
          records = actor_records_by_id(klass, ids)
          typed_rows.each do |row|
            record = records[row.actor_id.to_s]
            cache[actor_cache_key(row)] = actor_record_label(record) || fallback_actor_label(row)
          end
        end
      end

      def actor_records_by_id(klass, ids)
        return {} unless klass.is_a?(Class) && klass.respond_to?(:where)

        klass.where(id: ids).index_by { |record| record.id.to_s }
      rescue StandardError
        {}
      end

      def actor_record_label(record)
        return unless record

        record.try(:name).presence || record.try(:email).presence
      end

      def actor_cache_key(row)
        [row.actor_type.to_s, row.actor_id.to_s]
      end

      def fallback_actor_label(row)
        [row.actor_type, row.actor_id].compact_blank.join(" ")
      end
    end
  end
end
