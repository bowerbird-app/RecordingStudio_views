# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module ActorLabels
        def actor_value(row, context = nil, cache = nil)
          return ANONYMOUS_ACTOR if row.actor_id.blank?

          cache ||= context.actor_label_cache if context.respond_to?(:actor_label_cache)
          cache ||= {}
          preload_actor_labels(cache, actor_rows_for_page(context, row))
          cache[actor_cache_key(row)] || fallback_actor_label(row)
        end

        def actor_rows_for_page(context, row)
          rows = context&.table_result&.rows
          Array(rows.presence || [row])
        end

        def preload_actor_labels(cache, rows)
          pending_rows_by_type(cache, rows).each do |type, typed_rows|
            fill_labels_for_type(cache, type, typed_rows)
          end
        end

        def pending_rows_by_type(cache, rows)
          Array(rows)
            .select { |row| row.actor_id.present? && !cache.key?(actor_cache_key(row)) }
            .group_by { |row| row.actor_type.to_s }
        end

        def fill_labels_for_type(cache, type, typed_rows)
          return if type.blank?

          ids = typed_rows.map { |row| row.actor_id.to_s }.uniq
          records = actor_records_by_id(type.safe_constantize, ids)
          typed_rows.each do |row|
            cache[actor_cache_key(row)] = label_for_actor_row(row, records)
          end
        end

        def label_for_actor_row(row, records)
          actor_record_label(records[row.actor_id.to_s]) || fallback_actor_label(row)
        end

        def actor_records_by_id(klass, ids)
          return {} unless klass.is_a?(Class) && klass.respond_to?(:where)

          klass.where(id: ids).index_by { |record| record.id.to_s }
        rescue StandardError
          {}
        end

        def actor_record_label(record)
          return unless record

          record.try(:name).presence || record.try(:email).presence
        end

        def actor_cache_key(row)
          [row.actor_type.to_s, row.actor_id.to_s]
        end

        def fallback_actor_label(row)
          [row.actor_type, row.actor_id].compact_blank.join(" ")
        end
      end
    end
  end
end
