# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      PUBLIC = "Public"
      PRIVATE = "Private"
      SITE_ROOT_LABEL = "Site"
      ANONYMOUS_ACTOR = "Anonymous"
      VISITOR_TOKEN_KIND = "Token"

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
        key = value.to_s.strip
        return relation if key.empty?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(key)}%"
        relation.where("page_key ILIKE ?", pattern)
      end

      def filter_by_visibility(relation, value)
        case value.to_s
        when PUBLIC
          relation.where(actor_id: [nil, ""])
        when PRIVATE
          relation.where.not(actor_id: [nil, ""])
        else
          relation
        end
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

      def target_value(row, _context)
        [row.resource_type, row.page_key].compact_blank.join(" ")
      end

      def actor_value(row, _context)
        return ANONYMOUS_ACTOR if row.actor_id.blank?

        [row.actor_type, row.actor_id].compact_blank.join(" ")
      end

      def visitor_kind_value(row, _context)
        VISITOR_TOKEN_KIND if row.visitor_token_digest.present?
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
