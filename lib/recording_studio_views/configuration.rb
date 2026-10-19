# frozen_string_literal: true

module RecordingStudioViews
  class Configuration
    CONTEXT_VERSION = 1
    DEFAULT_TOKEN_TTL = 6.hours
    DEDUP_WINDOW = 24.hours
    MAX_PAYLOAD_BYTES = 4_096
    PATH_LIMIT = 2_048
    PAGE_KEY_LIMIT = 128
    RESOURCE_TYPE_LIMIT = 128
    ACTOR_TYPE_LIMIT = 128

    attr_accessor :api_key, :enable_feature_x, :timeout, :hooks,
                  :recording_resolver, :root_page_resolver, :site_page_resolver,
                  :root_ownership_policy, :tracking_access_policy, :consent_predicate,
                  :actor_resolver, :visitor_token_digest_resolver, :skip_paths,
                  :bot_filter, :token_ttl, :site_tracking_enabled,
                  :excluded_controller_paths

    def initialize
      @api_key = ENV.fetch("RECORDING_STUDIO_VIEWS_API_KEY", nil)
      @enable_feature_x = false
      @timeout = 5
      @hooks = RecordingStudio::Hooks.new
      @token_ttl = DEFAULT_TOKEN_TTL
      @site_tracking_enabled = false
      @skip_paths = [%r{\A/up\z}, %r{\A/assets/}, %r{\A/rails/}, %r{\A/recording_studio_views/}]
      @excluded_controller_paths = %w[rails/health rails/pwa]
      @recording_resolver = ->(controller) { default_recording_resolver(controller) }
      @root_page_resolver = ->(controller) { default_named_resolver(:current_root_page, controller) }
      @site_page_resolver = ->(controller) { default_named_resolver(:current_site_page, controller) }
      @root_ownership_policy = ->(_controller, _root) { true }
      @tracking_access_policy = ->(_request, _context, _actor) { :deny }
      @consent_predicate = ->(_request) { true }
      @actor_resolver = ->(controller) { default_actor(controller) }
      @visitor_token_digest_resolver = nil
      @bot_filter = BotFilter
    end

    def to_h
      {
        api_key: api_key,
        enable_feature_x: enable_feature_x,
        timeout: timeout,
        token_ttl: token_ttl,
        site_tracking_enabled: site_tracking_enabled,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    private

    def default_recording_resolver(controller)
      return unless controller.respond_to?(:current_recording)

      controller.current_recording
    end

    def default_named_resolver(method_name, controller)
      return unless controller.respond_to?(method_name)

      controller.public_send(method_name)
    end

    def default_actor(controller)
      named_actor(controller, :current_actor) ||
        current_attributes_actor ||
        named_actor(controller, :current_user) ||
        warden_actor(controller)
    end

    def named_actor(controller, method_name)
      return unless controller.respond_to?(method_name)

      actor = controller.public_send(method_name)
      actor if actor.present?
    end

    def current_attributes_actor
      return unless defined?(Current) && Current.respond_to?(:actor)

      actor = Current.actor
      actor if actor.present?
    end

    def warden_actor(controller)
      return unless controller.respond_to?(:request)

      warden = controller.request.env["warden"]
      warden.user if warden.respond_to?(:user)
    end
  end
end
