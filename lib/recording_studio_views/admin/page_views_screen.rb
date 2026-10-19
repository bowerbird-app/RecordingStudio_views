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
      PATH_FILTER = lambda { |relation, value, _context|
        Queries.filter_by_path(relation, value)
      }
      VISIT_KIND_FILTER = lambda { |relation, value, _context|
        Queries.filter_by_visit_kind(relation, value)
      }

      query { |_context| Queries.view_logs }

      filter :date_range, field: :occurred_at, default: :last_30_days
      filter :group_by, values: %i[day week month], default: :day

      chart do
        title "Page views over time"
        type :line
        series do |context|
          range = context.filter_value(:date_range)
          Queries.screen_page_views_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day,
            start_date: range&.start_date,
            end_date: range&.end_date
          )
        end
      end

      table do
        title "Page views"
        filter :root, options: -> { Queries.root_filter_options }, apply: ROOT_FILTER
        filter :resource_type, options: -> { Queries.resource_type_filter_options }, apply: RESOURCE_TYPE_FILTER
        filter :page_key, apply: PAGE_KEY_FILTER
        filter :path, apply: PATH_FILTER
        filter :visit_kind, options: -> { Queries.visit_kind_filter_options }, apply: VISIT_KIND_FILTER
        column :occurred_at, title: "Time", value: ->(row, context) { Queries.occurred_at_value(row, context) }
        column :root, title: "Root", sortable: false, value: ->(row, context) { Queries.root_value(row, context) }
        column :page_key, title: "Page", sortable: false, value: ->(row, context) { Queries.page_key_value(row, context) }
        column :resource_type, title: "Resource type", sortable: false,
                               value: ->(row, context) { Queries.resource_type_value(row, context) }
        column :path, title: "Path", sortable: false, value: ->(row, context) { Queries.path_value(row, context) }
        column :actor, title: "Actor", sortable: false, value: ->(row, context) { Queries.actor_value(row, context) }
        paginate per_page: 25
        default_sort :occurred_at, direction: :desc
      end
    end
  end
end
