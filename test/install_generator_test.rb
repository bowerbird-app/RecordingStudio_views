# frozen_string_literal: true

require "test_helper"
require "generators/recording_studio_views/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_views/install/templates/INSTALL.md",
    __dir__
  )

  def build_generator(destination_root, options = {})
    RecordingStudioViews::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_install_does_not_mount_the_sample_engine
    generator_path = "../lib/generators/recording_studio_views/install/install_generator.rb"
    source = File.read(File.expand_path(generator_path, __dir__))

    refute_includes source, "mount RecordingStudioViews::Engine"
    refute_includes source, "def mount_engine"
  end

  def test_install_does_not_inject_tailwind_sources
    generator_path = "../lib/generators/recording_studio_views/install/install_generator.rb"
    source = File.read(File.expand_path(generator_path, __dir__))

    refute_includes source, "def add_tailwind_source"
    refute_includes source, "@source"
    refute_includes source, "tailwindcss"
    refute_respond_to build_generator("/tmp"), :add_tailwind_source
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_install_guide_includes_migration_and_host_setup_steps
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "bin/rails generate recording_studio_views:migrations"
    assert_includes install_guide, "bin/rails db:migrate"
    assert_includes install_guide, "recording_studio_track_views"
    assert_includes install_guide, "recording_studio_recordable"
    refute_includes install_guide, "RecordingStudio v3"
  end

  def test_initializer_template_wires_geoip_path_and_maxmind_credentials
    template = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_views/install/templates/recording_studio_views_initializer.rb",
        __dir__
      )
    )

    assert_includes template, 'config.geoip_database_path = Rails.root.join("db/GeoLite2-City.mmdb")'
    assert_includes template, "config.maxmind_account_id = Rails.application.credentials.dig(:maxmind, :account_id)"
    assert_includes template, "config.maxmind_license_key = Rails.application.credentials.dig(:maxmind, :license_key)"
    assert_includes template, "config.rate_limiting_enabled"
    assert_includes template, "config.rate_limit_store"
    assert_includes template, "config.token_ttl"
  end
end
