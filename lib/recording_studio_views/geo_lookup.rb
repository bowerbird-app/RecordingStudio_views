# frozen_string_literal: true

require "maxmind/db"

module RecordingStudioViews
  module GeoLookup
    MUTEX = Mutex.new

    module_function

    def call(ip)
      return empty unless RecordingStudioViews.configuration.geo_enabled?
      return empty if ip.blank?

      record = reader&.get(ip.to_s)
      return empty if record.blank?

      location = record["location"] || {}
      {
        country: name_for(record["country"]),
        region: name_for(Array(record["subdivisions"]).first),
        city: name_for(record["city"]),
        latitude: location["latitude"],
        longitude: location["longitude"]
      }
    rescue StandardError
      empty
    end

    def reset!
      MUTEX.synchronize do
        @reader&.close
      rescue StandardError
        nil
      ensure
        @reader = nil
        @reader_path = nil
      end
    end

    def empty
      { country: nil, region: nil, city: nil, latitude: nil, longitude: nil }
    end

    def name_for(node)
      return if node.blank?

      names = node["names"]
      english = names.is_a?(Hash) ? names["en"] : nil
      value = english.presence || node["iso_code"]
      return if value.blank?

      value.to_s[0, Configuration::GEO_NAME_LIMIT]
    end

    def reader
      path = RecordingStudioViews.configuration.geoip_database_path.to_s
      return if path.blank?
      return unless File.file?(path)

      MUTEX.synchronize do
        return @reader if @reader && @reader_path == path

        @reader&.close
        @reader = MaxMind::DB.new(path, mode: MaxMind::DB::MODE_MEMORY)
        @reader_path = path
        @reader
      rescue StandardError
        @reader = nil
        @reader_path = nil
        nil
      end
    end
  end
end
