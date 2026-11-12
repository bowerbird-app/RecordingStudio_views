# frozen_string_literal: true

require "recording_studio_views/admin/queries"

module RecordingStudioViews
  module Metrics
    RESOURCE = :views
    API = :operations
    EXPOSE = { api: [API] }.freeze
    AUTHORIZE = ->(context) { RecordingStudioViews::Metrics.authorized?(context) }
    TOTAL_DESCRIPTION =
      "All-time views from daily summaries plus raw rows not yet aggregated."
    SERIES_DESCRIPTION =
      "Daily views in UTC from daily summaries, plus raw rows for days not yet aggregated."

    module_function

    def register!
      RecordingStudioMetrics.register(
        RESOURCE,
        model: ViewLog,
        blast_radius: :site,
        api_authorize: AUTHORIZE
      ) { RecordingStudioViews::Metrics.define_views(self) }
    end

    def define_views(dsl)
      define_total_views(dsl)
      define_page_views_over_time(dsl)
    end

    def define_total_views(dsl)
      dsl.custom :total_views,
                 result_type: :scalar,
                 title: "Total views",
                 description: TOTAL_DESCRIPTION,
                 expose: EXPOSE,
                 &total_views_calculator
    end

    def define_page_views_over_time(dsl)
      dsl.custom :page_views_over_time,
                 result_type: :timeseries,
                 title: "Page views over time",
                 description: SERIES_DESCRIPTION,
                 expose: EXPOSE,
                 &page_views_over_time_calculator
    end

    def authorized?(context)
      grant = context.try(:access_grant)
      actor = grant.respond_to?(:actor) ? grant.actor : context.try(:actor)
      return false if actor.blank?

      scoped = Admin::Queries.accessible_root_relation(ViewLog, actor: actor)
      !scoped.null_relation?
    end

    def total_views_calculator
      lambda do |_relation, context|
        Admin::Queries.total_views(actor: context.actor)
      end
    end

    def page_views_over_time_calculator
      lambda do |_relation, context|
        Admin::Queries.page_views_over_time_series(actor: context.actor).first.fetch(:data)
      end
    end
  end
end
