# frozen_string_literal: true

require_relative "admin/queries"
require_relative "admin/section"
require_relative "admin/page_views_screen"
require_relative "admin/widgets"

module RecordingStudioViews
  module Admin
    module_function

    def register!
      return unless defined?(::RecordingStudioAdmin)

      RecordingStudioAdmin.register_section(Section)
      RecordingStudioAdmin.register_screen(PageViewsScreen)
      RecordingStudioAdmin.register_widget(Widgets::PAGE_VIEWS_OVER_TIME)
      RecordingStudioAdmin.register_widget(Widgets::TOTAL_VIEWS)
    end
  end
end
