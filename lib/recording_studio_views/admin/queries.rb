# frozen_string_literal: true

require_relative "queries/actor_labels"
require_relative "queries/chart_filter_copy"
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
        include ChartFilterCopy
        include ChartSeries
        include ChartSummaries
        include Filters
        include RowValues

        def view_logs(actor: nil, access_recording: nil)
          scoped_view_logs(actor: actor, access_recording: access_recording).order(occurred_at: :desc)
        end

        def total_views(actor: nil, access_recording: nil)
          logs = scoped_view_logs(actor: actor, access_recording: access_recording)
          scoped_summaries(actor: actor, access_recording: access_recording).sum(:views).to_i +
            unsummarized_view_logs(logs, actor: actor, access_recording: access_recording).count
        end

        def page_views_over_time_series(day_range: default_day_range, actor: nil, access_recording: nil)
          counts = views_by_day_utc(day_range, actor: actor, access_recording: access_recording)
          data = day_range.map { |day| { x: day, y: counts[day].to_i } }
          [{ name: "Page views", data: data }]
        end

        def views_by_day_utc(day_range, actor: nil, access_recording: nil)
          day_sql = "(#{quoted_occurred_at} AT TIME ZONE 'UTC')::date"
          relation = scoped_view_logs(actor: actor, access_recording: access_recording)
                     .where("#{day_sql} BETWEEN ? AND ?", day_range.begin, day_range.end)
          views_by_bucket_utc(
            relation,
            :day,
            range_start: day_range.begin,
            range_end: day_range.end,
            actor: actor,
            access_recording: access_recording
          )
        end

        def scoped_view_logs(actor: nil, access_recording: nil)
          accessible_root_relation(ViewLog, actor: actor, access_recording: access_recording)
        end

        def scoped_summaries(actor: nil, access_recording: nil)
          accessible_root_relation(DailyViewSummary, actor: actor, access_recording: access_recording)
        end

        def accessible_root_relation(relation, actor: nil, access_recording: nil)
          return relation.none unless defined?(::RecordingStudioAccessible)

          actor = resolve_query_actor(actor)
          return relation.none if actor.blank?

          if access_recording &&
             RecordingStudioAccessible.authorized?(actor: actor, recording: access_recording, role: :view)
            return relation.all
          end

          root_ids = RecordingStudioAccessible.root_recording_ids_for(actor: actor, minimum_role: :view)
          return relation.none if root_ids.blank?

          relation.where(root_recording_id: root_ids)
        end

        def resolve_query_actor(actor)
          return actor if actor.present?
          return unless defined?(::Current) && ::Current.respond_to?(:actor)

          ::Current.actor
        end

        def default_day_range
          today = Time.now.utc.to_date
          (today - 29)..today
        end

        def root_filter_options(actor: nil, access_recording: nil)
          ids = scoped_view_logs(actor: actor, access_recording: access_recording).distinct.pluck(:root_recording_id)
          labels = ids.map { |id| root_label(id) }
          labels.uniq.sort
        end

        def resource_type_filter_options(actor: nil, access_recording: nil)
          scoped_view_logs(actor: actor, access_recording: access_recording)
            .where.not(resource_type: [nil, ""])
            .distinct.order(:resource_type).pluck(:resource_type)
        end

        def root_label(root_recording_id)
          return SITE_ROOT_LABEL if root_recording_id.blank?

          recording = RecordingStudio::Recording.find_by(id: root_recording_id)
          recordable = recording&.recordable
          name = recordable&.try(:name) || recordable&.try(:title)
          name.presence || root_recording_id.to_s
        end

        def root_id_for_label(label, actor: nil, access_recording: nil)
          scoped_view_logs(actor: actor, access_recording: access_recording)
            .distinct.pluck(:root_recording_id).compact.find do |id|
            root_label(id) == label
          end
        end
      end
    end
  end
end
