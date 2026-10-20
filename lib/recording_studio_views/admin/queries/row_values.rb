# frozen_string_literal: true

module RecordingStudioViews
  module Admin
    module Queries
      module RowValues
        def occurred_at_value(row, _context)
          row.occurred_at&.utc
        end

        def root_value(row, _context)
          root_label(row.root_recording_id)
        end

        def page_key_value(row, _context)
          row.page_key
        end

        def resource_type_value(row, _context)
          row.resource_type
        end

        def path_value(row, _context)
          row.path
        end

        def ip_value(row, _context)
          row.ip
        end

        def user_agent_value(row, _context)
          row.user_agent
        end

        def browser_value(row, _context)
          row.browser
        end

        def os_value(row, _context)
          row.os
        end

        def os_version_value(row, _context)
          row.os_version
        end

        def utm_source_value(row, _context)
          row.utm_source
        end

        def utm_medium_value(row, _context)
          row.utm_medium
        end

        def utm_term_value(row, _context)
          row.utm_term
        end

        def utm_content_value(row, _context)
          row.utm_content
        end

        def utm_campaign_value(row, _context)
          row.utm_campaign
        end

        def device_type_value(row, _context)
          row.device_type
        end

        def country_value(row, _context)
          row.country
        end

        def region_value(row, _context)
          row.region
        end

        def city_value(row, _context)
          row.city
        end

        def latitude_value(row, _context)
          row.latitude
        end

        def longitude_value(row, _context)
          row.longitude
        end
      end
    end
  end
end
