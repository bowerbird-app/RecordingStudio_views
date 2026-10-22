# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Widgets
      PAGE_VIEWS_OVER_TIME = RecordingStudioAdmin::Widget.new(
        "widgets.views.page_views_over_time",
        blast_radius: :site
      ) do
        type :chart
        title "Page views over time"
        info "Daily views in UTC from daily summaries, plus raw rows for days not yet aggregated."
        chart_type :line
        hide_change
        series { Queries.page_views_over_time_series }
        chart_options do
          {
            xaxis: { labels: { show: false } },
            tooltip: { enabled: true }
          }
        end
        link_to { |context| context.admin_screen_path("views_page_views") }
      end

      TOTAL_VIEWS = RecordingStudioAdmin::Widget.new(
        "widgets.views.total_views",
        blast_radius: :site
      ) do
        type :number
        title "Total views"
        info "All-time views from daily summaries plus raw rows not yet aggregated."
        value { Queries.total_views }
        hide_change
        hide_period
        link_to { |context| context.admin_screen_path("views_page_views") }
      end
    end
  end
end
