# frozen_string_literal: true

require "test_helper"
require "yaml"
require "digest"
require "active_support/encrypted_file"

class DummyCredentialsTest < Minitest::Test
  PLACEHOLDER = "dev_placeholder"
  SHARED_CREDENTIALS = "test/dummy/config/credentials.yml.enc"
  DEVELOPMENT_CREDENTIALS = "test/dummy/config/credentials/development.yml.enc"
  PRODUCTION_CREDENTIALS = "test/dummy/config/credentials/production.yml.enc"
  SHARED_SHA = "2526ea339b8500895f0030936c9f3aa1cc62dd18d56be399ed6bcab8c38003cf"
  DEVELOPMENT_SHA = "15a5349d8546250c74a8d4f140bb8b1b24dae10827faf08836126d542ab3ed92"
  PRODUCTION_SHA = "d21f61586a9e207fa56b91e0693c84bf52040d4446409105bf07f999d971fa7c"

  def test_only_dummy_credentials_files_are_committed
    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- '*.yml.enc'`.split("\n").reject(&:empty?)
    end

    assert_equal [SHARED_CREDENTIALS, DEVELOPMENT_CREDENTIALS, PRODUCTION_CREDENTIALS].sort, tracked.sort
  end

  def test_env_credentials_match_supplied_ciphertext
    root = File.expand_path("..", __dir__)
    shared = File.join(root, SHARED_CREDENTIALS)
    development = File.join(root, DEVELOPMENT_CREDENTIALS)
    production = File.join(root, PRODUCTION_CREDENTIALS)

    assert File.exist?(shared)
    assert File.exist?(development)
    assert File.exist?(production)
    assert_equal SHARED_SHA, Digest::SHA256.file(shared).hexdigest
    assert_equal DEVELOPMENT_SHA, Digest::SHA256.file(development).hexdigest
    assert_equal PRODUCTION_SHA, Digest::SHA256.file(production).hexdigest
  end

  def test_encrypted_credentials_file_is_present
    path = dummy_credentials_path
    assert File.exist?(path), "Expected #{path} so new gems reuse the shared dummy credentials"
    assert File.size(path).positive?
  end

  def test_master_key_is_gitignored_and_untracked
    gitignore = File.read(File.expand_path("../.gitignore", __dir__))
    assert_includes gitignore, "test/dummy/config/master.key"
    assert_includes gitignore, "config/master.key"
    assert_includes gitignore, "config/credentials/*.key"
    assert_includes gitignore, "test/dummy/config/credentials/*.key"
    assert_includes gitignore, "test/dummy/db/GeoLite2-City.mmdb"

    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- config/master.key test/dummy/config/master.key \
        config/credentials/*.key test/dummy/config/credentials/*.key`.strip
    end
    assert_equal "", tracked, "credential keys must not be committed"
  end

  def test_dummy_credentials_decrypt_when_master_key_is_available
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    parsed = YAML.safe_load(
      ActiveSupport::EncryptedFile.new(
        content_path: dummy_credentials_path,
        key_path: dummy_master_key_path,
        env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true
      ).read
    )

    assert_operator parsed.fetch("secret_key_base").to_s.length, :>=, 64
    assert_equal PLACEHOLDER, parsed.dig("recording_studio_views", "api_key")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "user_name")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "password")
    assert_equal PLACEHOLDER, parsed.dig("aws", "access_key_id")
    assert_equal PLACEHOLDER, parsed.dig("aws", "secret_access_key")
  end

  private

  def dummy_credentials_path
    File.expand_path("../test/dummy/config/credentials.yml.enc", __dir__)
  end

  def dummy_master_key_path
    File.expand_path("../test/dummy/config/master.key", __dir__)
  end

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(dummy_master_key_path)
  end
end
