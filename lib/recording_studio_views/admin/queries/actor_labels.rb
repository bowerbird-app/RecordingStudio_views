# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module ActorLabels
        def actor_value(row, _context = nil)
          return ANONYMOUS_ACTOR if row.actor_id.blank?

          records = actor_records_by_id(row.actor_type.to_s.safe_constantize, [row.actor_id.to_s])
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

        def fallback_actor_label(row)
          [row.actor_type, row.actor_id].compact_blank.join(" ")
        end
      end
    end
  end
end
