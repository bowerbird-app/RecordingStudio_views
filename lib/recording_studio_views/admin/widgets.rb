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
        info "Daily views in UTC from raw view logs."
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

      PAGES_OVER_TIME = RecordingStudioAdmin::Widget.new(
        "widgets.views.pages_over_time",
        blast_radius: :site
      ) do
        type :chart
        title "Pages over time"
        info "Daily views for named pages, in UTC."
        chart_type :line
        hide_change
        series { Queries.plain_pages_over_time_series }
        chart_options do
          {
            xaxis: { labels: { show: false } },
            tooltip: { enabled: true }
          }
        end
        link_to { |context| context.admin_screen_path("views_pages") }
      end

      TOP_PAGES = RecordingStudioAdmin::Widget.new(
        "widgets.views.top_pages",
        blast_radius: :site
      ) do
        type :list
        title "Top pages"
        info "Named pages with the most views."
        hide_change
        hide_period
        items { Queries.top_plain_page_items }
        link_to { |context| context.admin_screen_path("views_pages") }
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
