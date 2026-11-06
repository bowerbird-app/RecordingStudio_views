# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module ChartFilterCopy
        def copy_root_recording_filter(normalized, filters, actor: nil, access_recording: nil)
          if filters.key?(:root_recording_id)
            normalized[:root_recording_id] = filters[:root_recording_id]
          elsif chart_filter_present?(filters[:root])
            label = filters[:root].to_s.strip
            normalized[:root_recording_id] = if label == SITE_ROOT_LABEL
                                               nil
                                             else
                                               root_id_for_label(
                                                 label, actor: actor, access_recording: access_recording
                                               )
                                             end
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
