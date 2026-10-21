# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    class PagesScreen < RecordingStudioAdmin::Screen
      key "views_pages"
      icon :table_cells
      title "Pages"
      subtitle "Named pages, like home and sign-in."
      blast_radius :site

      query { |_context| Queries.top_plain_pages }

      chart do
        title "Pages over time"
        type :line
        series do |_context|
          Queries.plain_pages_over_time_series
        end
      end

      table do
        title "Top pages"
        column :page_key, title: "Page",
                          value: ->(row, _context) { row.page_key }
        column :views, title: "Views",
                       value: ->(row, _context) { row.views.to_i }
        paginate per_page: 25
      end
    end
  end
end
