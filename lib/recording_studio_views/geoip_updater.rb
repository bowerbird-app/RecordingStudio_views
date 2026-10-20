# frozen_string_literal: true

require "fileutils"
require "net/http"
require "rubygems/package"
require "stringio"
require "uri"
require "zlib"

module RecordingStudioViews
  class GeoipUpdater
    class Error < StandardError; end

    DOWNLOAD_URL = "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
    DOWNLOAD_HOST = URI(DOWNLOAD_URL).host
    MMDB_FILENAME = "GeoLite2-City.mmdb"
    MAX_REDIRECTS = 8

    def self.call(force: false, out: $stdout)
      new(force: force, out: out).call
    end

    def initialize(force: false, out: $stdout)
      @force = force
      @out = out
      @config = RecordingStudioViews.configuration
    end

    def call
      validate_config!
      return skip_fresh if skip_fresh?

      replace_database
      RecordingStudioViews::GeoLookup.reset!
      @out.puts "Updated GeoLite2 City at #{destination}"
    end

    def http_get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(account_id, license_key) if uri.host == DOWNLOAD_HOST
        http.request(request)
      end
    end

    private

    def validate_config!
      raise Error, "Set config.geoip_database_path before updating GeoLite2 City." if destination.blank?
      raise Error, "Set config.maxmind_account_id before updating GeoLite2 City." if account_id.blank?
      raise Error, "Set config.maxmind_license_key before updating GeoLite2 City." if license_key.blank?
    end

    def skip_fresh?
      return false if @force
      return false unless File.file?(destination)

      File.mtime(destination) > Time.now - @config.geoip_max_age
    end

    def skip_fresh
      @out.puts "Skipping GeoLite2 City update; #{destination} is newer than " \
                "config.geoip_max_age. Set FORCE=1 to download anyway."
    end

    def replace_database
      tmp_path = "#{destination}.tmp"
      FileUtils.mkdir_p(File.dirname(destination))
      extract_mmdb(download_archive, tmp_path)
      File.rename(tmp_path, destination)
    ensure
      FileUtils.rm_f(tmp_path) if tmp_path
    end

    def download_archive
      uri = URI(DOWNLOAD_URL)
      MAX_REDIRECTS.times do
        response = http_get(uri)
        return response.body if response.is_a?(Net::HTTPSuccess)

        raise Error, "GeoLite2 City download failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPRedirection)

        location = response["location"]
        raise Error, "GeoLite2 City download redirected without a Location header" if location.blank?

        uri = URI.join(uri.to_s, location)
      end

      raise Error, "GeoLite2 City download redirected too many times"
    rescue Error
      raise
    rescue StandardError
      raise Error, "GeoLite2 City download failed"
    end

    def extract_mmdb(archive, tmp_path)
      found = false
      Zlib::GzipReader.wrap(StringIO.new(archive)) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            next unless entry.file? && File.basename(entry.full_name) == MMDB_FILENAME

            File.open(tmp_path, "wb") { |file| IO.copy_stream(entry, file) }
            found = true
            break
          end
        end
      end

      raise Error, "GeoLite2 City archive did not contain #{MMDB_FILENAME}" unless found
    rescue Error
      raise
    rescue StandardError
      raise Error, "GeoLite2 City archive could not be read"
    end

    def destination
      @config.geoip_database_path.to_s.presence
    end

    def account_id
      @config.maxmind_account_id.to_s.presence
    end

    def license_key
      @config.maxmind_license_key.to_s.presence
    end
  end
end
