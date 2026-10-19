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
           style: :primary

      widget "widgets.views.page_views_over_time"
      widget "widgets.views.total_views"
    end
  end
end
