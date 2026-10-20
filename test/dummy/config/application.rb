require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Env-specific credentials need config/credentials/#{Rails.env}.key.
    # CI and test only have the shared master.key, so keep credentials.yml.enc.
    env_credentials_key = config.root.join("config/credentials/#{Rails.env}.key")
    unless env_credentials_key.exist?
      config.credentials.content_path = config.root.join("config/credentials.yml.enc")
      config.credentials.key_path = config.root.join("config/master.key")
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure generators to use UUID primary keys
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
