# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    class Section < RecordingStudioAdmin::Section
      key "views"
      icon :chart_bar
      title "Views"
      subtitle "What people opened, by day."
      blast_radius :site

      link :views_page_views,
           text: "Page views",
           url: ->(context) { context.admin_screen_path("views_page_views") },
           style: :secondary
      link :views_pages,
           text: "Pages",
           url: ->(context) { context.admin_screen_path("views_pages") },
           style: :secondary

      widget "widgets.views.page_views_over_time", view_variant: :compact
      widget "widgets.views.total_views", view_variant: :compact
      widget "widgets.views.pages_over_time", view_variant: :compact
      widget "widgets.views.top_pages", view_variant: :compact
    end
  end
end
