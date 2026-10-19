# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    class PageViewsScreen < RecordingStudioAdmin::Screen
      key "views_page_views"
      icon :table_cells
      title "Page views"
      subtitle "Each stored view, newest first."
      blast_radius :site

      ROOT_FILTER = lambda { |relation, value, _context|
        Queries.filter_by_root(relation, value)
      }
      RESOURCE_TYPE_FILTER = lambda { |relation, value, _context|
        Queries.filter_by_resource_type(relation, value)
      }
      PAGE_KEY_FILTER = lambda { |relation, value, _context|
        Queries.filter_by_page_key(relation, value)
      }
      VISIBILITY_FILTER = lambda { |relation, value, _context|
        Queries.filter_by_visibility(relation, value)
      }

      query { |_context| Queries.view_logs }

      filter :date_range, field: :occurred_at, default: :last_30_days

      table do
        title "Page views"
        filter :root, options: -> { Queries.root_filter_options }, apply: ROOT_FILTER
        filter :resource_type, options: -> { Queries.resource_type_filter_options }, apply: RESOURCE_TYPE_FILTER
        filter :page_key, apply: PAGE_KEY_FILTER
        filter :visibility, options: [Queries::PUBLIC, Queries::PRIVATE], apply: VISIBILITY_FILTER
        column :occurred_at, title: "Time", value: ->(row, context) { Queries.occurred_at_value(row, context) }
        column :root, title: "Root", sortable: false, value: ->(row, context) { Queries.root_value(row, context) }
        column :target, title: "Page", sortable: false, value: ->(row, context) { Queries.target_value(row, context) }
        column :actor, title: "Actor", sortable: false, value: ->(row, context) { Queries.actor_value(row, context) }
        column :visitor_kind, title: "Visitor kind", sortable: false,
                              value: ->(row, context) { Queries.visitor_kind_value(row, context) }
        paginate per_page: 25
        default_sort :occurred_at, direction: :desc
      end
    end
  end
end
