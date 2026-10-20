# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "stringio"
require "tmpdir"
require "zlib"
require "rubygems/package"

class GeoipUpdaterTest < Minitest::Test
  MMDB_NAME = "GeoLite2-City.mmdb"
  ACCOUNT = "account-id"
  LICENSE = "license-key-secret"

  FakeResponse = Struct.new(:code, :body, :location) do
    def is_a?(klass)
      case klass.name
      when "Net::HTTPSuccess" then Integer(code).between?(200, 299)
      when "Net::HTTPRedirection" then Integer(code).between?(300, 399)
      else super
      end
    end

    def [](header)
      header.to_s.downcase == "location" ? location : nil
    end
  end

  def setup
    @config = RecordingStudioViews.configuration
    @previous = {
      path: @config.geoip_database_path,
      account: @config.maxmind_account_id,
      key: @config.maxmind_license_key,
      max_age: @config.geoip_max_age
    }
    @tmpdir = Dir.mktmpdir("geoip-updater")
    @destination = File.join(@tmpdir, "db", MMDB_NAME)
    @out = StringIO.new
    RecordingStudioViews::GeoLookup.reset!
  end

  def teardown
    @config.geoip_database_path = @previous[:path]
    @config.maxmind_account_id = @previous[:account]
    @config.maxmind_license_key = @previous[:key]
    @config.geoip_max_age = @previous[:max_age]
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
    RecordingStudioViews::GeoLookup.reset!
  end

  def test_skips_when_file_is_fresh
    write_destination("stale-should-not-change")
    configure!
    instance = updater(force: false)
    http_called = false

    instance.stub(:http_get, lambda { |_uri|
      http_called = true
      flunk "HTTP ran"
    }) { instance.call }

    refute http_called
    assert_equal "stale-should-not-change", File.read(@destination)
    assert_includes @out.string, "Skipping GeoLite2 City update"
    assert_includes @out.string, "FORCE=1"
    refute_includes @out.string, LICENSE
  end

  def test_force_downloads_when_file_is_fresh
    write_destination("old-bytes")
    configure!
    instance = updater(force: true)

    with_successful_http(instance, "new-bytes") { instance.call }

    assert_equal "new-bytes", File.read(@destination)
    assert_includes @out.string, "Updated GeoLite2 City"
    refute File.exist?("#{@destination}.tmp")
    refute_includes @out.string, LICENSE
  end

  def test_missing_path_exits_with_message
    configure!(path: nil)

    error = assert_raises(RecordingStudioViews::GeoipUpdater::Error) { updater.call }
    assert_equal "Set config.geoip_database_path before updating GeoLite2 City.", error.message
    refute_includes error.message, LICENSE
  end

  def test_missing_account_exits_with_message
    configure!(account: nil)

    error = assert_raises(RecordingStudioViews::GeoipUpdater::Error) { updater.call }
    assert_equal "Set config.maxmind_account_id before updating GeoLite2 City.", error.message
  end

  def test_missing_license_key_exits_with_message
    configure!(key: nil)

    error = assert_raises(RecordingStudioViews::GeoipUpdater::Error) { updater.call }
    assert_equal "Set config.maxmind_license_key before updating GeoLite2 City.", error.message
    refute_includes error.message, LICENSE
  end

  def test_success_creates_directory_and_writes_atomically
    configure!
    instance = updater
    reset_called = false

    RecordingStudioViews::GeoLookup.stub(:reset!, -> { reset_called = true }) do
      with_successful_http(instance, "city-db") { instance.call }
    end

    assert reset_called
    assert File.file?(@destination)
    assert_equal "city-db", File.read(@destination)
    refute File.exist?("#{@destination}.tmp")
    leftovers = Dir.glob(File.join(File.dirname(@destination), "*"))
    assert_equal [@destination], leftovers
  end

  def test_failure_keeps_the_old_file
    write_destination("keep-me")
    age_file(@destination, 8.days)
    configure!
    instance = updater

    instance.stub(:http_get, ->(_uri) { FakeResponse.new("500", "nope", nil) }) do
      error = assert_raises(RecordingStudioViews::GeoipUpdater::Error) { instance.call }
      assert_equal "GeoLite2 City download failed (HTTP 500)", error.message
    end

    assert_equal "keep-me", File.read(@destination)
    refute File.exist?("#{@destination}.tmp")
  end

  def test_follows_redirects_without_printing_the_key
    configure!
    instance = updater
    responses = {
      "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz" =>
        FakeResponse.new("302", nil, "https://mm-download.example/GeoLite2-City.tar.gz"),
      "https://mm-download.example/GeoLite2-City.tar.gz" =>
        FakeResponse.new("200", gzipped_tar("redirected-db"), nil)
    }

    instance.stub(:http_get, ->(uri) { responses.fetch(uri.to_s) }) { instance.call }

    assert_equal "redirected-db", File.read(@destination)
    refute_includes @out.string, LICENSE
  end

  def test_rake_task_wires_force_and_aborts_without_printing_the_key
    rake = File.read(File.expand_path("../lib/tasks/recording_studio_views_geoip.rake", __dir__))

    assert_includes rake, "namespace :recording_studio_views"
    assert_includes rake, "namespace :geoip"
    assert_includes rake, "task update: :environment"
    assert_includes rake, 'ENV["FORCE"] == "1"'
    assert_includes rake, "abort e.message"
    refute_includes rake, "license_key"
  end

  private

  def configure!(path: @destination, account: ACCOUNT, key: LICENSE)
    @config.geoip_database_path = path
    @config.maxmind_account_id = account
    @config.maxmind_license_key = key
    @config.geoip_max_age = 7.days
  end

  def updater(force: false)
    RecordingStudioViews::GeoipUpdater.new(force: force, out: @out)
  end

  def write_destination(contents)
    FileUtils.mkdir_p(File.dirname(@destination))
    File.write(@destination, contents)
  end

  def age_file(path, age)
    past = Time.now - age
    File.utime(past, past, path)
  end

  def with_successful_http(instance, contents, &)
    archive = gzipped_tar(contents)
    instance.stub(:http_get, ->(_uri) { FakeResponse.new("200", archive, nil) }, &)
  end

  def gzipped_tar(mmdb_contents)
    tar_io = StringIO.new(+"")
    Gem::Package::TarWriter.new(tar_io) do |tar|
      tar.add_file_simple("GeoLite2-City_20260101/#{MMDB_NAME}", 0o644, mmdb_contents.bytesize) do |io|
        io.write(mmdb_contents)
      end
    end

    gzip_io = StringIO.new(+"")
    gz = Zlib::GzipWriter.new(gzip_io)
    gz.write(tar_io.string)
    gz.close
    gzip_io.string
  end
end
