# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module Filters
        def filter_by_root(relation, value)
          label = value.to_s.strip
          return relation if label.empty?

          if label == SITE_ROOT_LABEL
            relation.where(root_recording_id: nil)
          else
            relation.where(root_recording_id: root_id_for_label(label))
          end
        end

        def filter_by_resource_type(relation, value)
          type = value.to_s.strip
          type.empty? ? relation : relation.where(resource_type: type)
        end

        def filter_by_page_key(relation, value)
          contains_match(relation, :page_key, value)
        end

        def filter_by_path(relation, value)
          contains_match(relation, :path, value)
        end

        def filter_by_visit_kind(relation, value)
          case value.to_s
          when ANONYMOUS_ACTOR
            relation.where(actor_id: [nil, ""])
          when SIGNED_IN
            relation.where.not(actor_id: [nil, ""])
          else
            relation
          end
        end

        def visit_kind_filter_options
          [SIGNED_IN, ANONYMOUS_ACTOR]
        end

        def chart_filters_from_screen(context)
          normalize_chart_filters(
            root: context.filter_value(:root),
            resource_type: context.filter_value(:resource_type),
            page_key_contains: context.filter_value(:page_key),
            path: context.filter_value(:path),
            visit_kind: context.filter_value(:visit_kind)
          )
        end

        def normalize_chart_filters(filters)
          filters = (filters || {}).to_h.transform_keys(&:to_sym)
          normalized = {}
          copy_root_recording_filter(normalized, filters)
          copy_present_chart_filters(
            normalized,
            filters,
            %i[recording_id resource_type page_key page_key_contains path visit_kind]
          )
          normalized
        end

        def apply_chart_filters_to_logs(relation, filters)
          relation = apply_equality_log_filters(relation, filters)
          if filters.key?(:page_key_contains)
            relation = contains_match(relation, :page_key, filters[:page_key_contains])
          end
          relation = filter_by_path(relation, filters[:path]) if filters.key?(:path)
          relation = filter_by_visit_kind(relation, filters[:visit_kind]) if filters.key?(:visit_kind)
          relation
        end

        def contains_match(relation, column, value)
          needle = value.to_s.strip
          return relation if needle.empty?

          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(needle)}%"
          quoted = ViewLog.connection.quote_column_name(column.to_s)
          relation.where("#{quoted} ILIKE ?", pattern)
        end

        def copy_root_recording_filter(normalized, filters)
          if filters.key?(:root_recording_id)
            normalized[:root_recording_id] = filters[:root_recording_id]
          elsif chart_filter_present?(filters[:root])
            label = filters[:root].to_s.strip
            normalized[:root_recording_id] = label == SITE_ROOT_LABEL ? nil : root_id_for_label(label)
          end
        end

        def copy_present_chart_filters(normalized, filters, keys)
          keys.each do |key|
            normalized[key] = filters[key] if chart_filter_present?(filters[key])
          end
        end

        def apply_equality_log_filters(relation, filters)
          %i[root_recording_id recording_id resource_type page_key].each do |column|
            relation = relation.where(column => filters[column]) if filters.key?(column)
          end
          relation
        end

        def chart_filter_present?(value)
          !(value.nil? || value.to_s.strip.empty?)
        end
      end
    end
  end
end
