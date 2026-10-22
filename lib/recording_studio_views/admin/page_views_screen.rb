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
      TABLE_COLUMNS = [
        [:occurred_at, "Time", true],
        [:root, "Root", false],
        [:page_key, "Page", false],
        [:resource_type, "Resource type", false],
        [:path, "Path", false],
        [:ip, "IP", false],
        [:user_agent, "User agent", false],
        [:browser, "Browser", false],
        [:os, "OS", false],
        [:os_version, "OS version", false],
        [:utm_source, "UTM source", false],
        [:utm_medium, "UTM medium", false],
        [:utm_term, "UTM term", false],
        [:utm_content, "UTM content", false],
        [:utm_campaign, "UTM campaign", false],
        [:device_type, "Device", false],
        [:country, "Country", false],
        [:region, "Region", false],
        [:city, "City", false],
        [:latitude, "Latitude", false],
        [:longitude, "Longitude", false],
        [:actor, "Actor", false]
      ].freeze

      query { |_context| Queries.view_logs }

      filter_presentation :modal, inline_count: 2
      filter :date_range, field: :occurred_at, default: :last_30_days
      filter :group_by, values: %i[day week month], default: :day
      filter :root, options: -> { Queries.root_filter_options }, apply: ROOT_FILTER
      filter :resource_type, options: -> { Queries.resource_type_filter_options }, apply: RESOURCE_TYPE_FILTER
      filter :visit_kind, options: -> { Queries.visit_kind_filter_options }, apply: VISIT_KIND_FILTER

      chart do
        title "Page views over time"
        type :line
        series do |context|
          range = context.filter_value(:date_range)
          Queries.screen_page_views_series(
            context.query_result.relation,
            filters: Queries.chart_filters_from_screen(context),
            bucket: context.filter_value(:group_by) || :day,
            start_date: range&.start_date,
            end_date: range&.end_date
          )
        end
      end

      table do
        title "Page views"
        filter :page_key, apply: PAGE_KEY_FILTER
        filter :path, apply: PATH_FILTER
        TABLE_COLUMNS.each do |key, title, sortable|
          value = if key == :actor
                    lambda do |row, context|
                      cache = {}
                      if context
                        unless context.respond_to?(:actor_label_cache)
                          context.define_singleton_method(:actor_label_cache) { @actor_label_cache ||= {} }
                        end
                        cache = context.actor_label_cache
                      end
                      Queries.actor_value(row, context, cache)
                    end
                  else
                    ->(row, context) { Queries.public_send(:"#{key}_value", row, context) }
                  end
          column key, title: title, sortable: sortable, value: value
        end
        paginate per_page: 25
        default_sort :occurred_at, direction: :desc
      end
    end
  end
end
