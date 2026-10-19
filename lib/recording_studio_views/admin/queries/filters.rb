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

        def filter_by_visibility(relation, value)
          filter_by_visit_kind(relation, visibility_to_visit_kind(value))
        end

        def filter_by_visit_kind(relation, value)
          case value.to_s
          when ANONYMOUS_ACTOR
            relation.where(actor_id: [nil, ""])
          when SIGNED_IN, PRIVATE
            relation.where.not(actor_id: [nil, ""])
          else
            relation
          end
        end

        def visit_kind_filter_options
          [SIGNED_IN, ANONYMOUS_ACTOR]
        end

        def contains_match(relation, column, value)
          needle = value.to_s.strip
          return relation if needle.empty?

          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(needle)}%"
          quoted = ViewLog.connection.quote_column_name(column.to_s)
          relation.where("#{quoted} ILIKE ?", pattern)
        end

        def visibility_to_visit_kind(value)
          case value.to_s
          when PUBLIC then ANONYMOUS_ACTOR
          when PRIVATE then SIGNED_IN
          else value
          end
        end
      end
    end
  end
end
