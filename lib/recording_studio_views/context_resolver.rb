# frozen_string_literal: true

module RecordingStudioViews
  class ContextResolver
    def initialize(controller)
      @controller = controller
      @config = RecordingStudioViews.configuration
    end

    def call
      return PageContext.skipped if excluded_request?
      return PageContext.skipped unless consent?

      recording_context || root_context || site_context || PageContext.skipped
    end

    private

    def excluded_request?
      path = @controller.request.path.to_s
      return true if @config.skip_paths.any? { |pattern| path.match?(pattern) }
      return true if @config.excluded_controller_paths.include?(@controller.controller_path)

      false
    end

    def consent?
      @config.consent_predicate.call(@controller.request)
    rescue StandardError
      false
    end

    def recording_context
      recording = resolve_recording
      return if recording.blank?
      return unless recording_enabled?(recording)

      root = recording_root(recording)
      return if root.blank?
      return unless owned_root?(root)

      PageContext.new(
        kind: :recording,
        recording_id: recording.id,
        root_recording_id: root.id,
        resource_type: clip(recordable_type(recording), Configuration::RESOURCE_TYPE_LIMIT),
        page_key: clip("recording", Configuration::PAGE_KEY_LIMIT),
        version: Configuration::CONTEXT_VERSION
      )
    end

    def root_context
      details = hashify(@config.root_page_resolver&.call(@controller))
      return if details.blank?

      root = resolve_root(details)
      return if root.blank?
      return unless owned_root?(root)

      PageContext.new(
        kind: :root,
        recording_id: nil,
        root_recording_id: root.id,
        resource_type: clip(details[:resource_type] || root.recordable_type, Configuration::RESOURCE_TYPE_LIMIT),
        page_key: clip(details[:page_key] || "root", Configuration::PAGE_KEY_LIMIT),
        version: Configuration::CONTEXT_VERSION
      )
    end

    def site_context
      return unless @config.site_tracking_enabled

      details = hashify(@config.site_page_resolver&.call(@controller))
      return if details.blank?
      return if details[:root_recording_id].present? || details[:root_recording].present?

      PageContext.new(
        kind: :site,
        recording_id: nil,
        root_recording_id: nil,
        resource_type: clip(details[:resource_type] || "Site", Configuration::RESOURCE_TYPE_LIMIT),
        page_key: clip(details[:page_key] || "site", Configuration::PAGE_KEY_LIMIT),
        version: Configuration::CONTEXT_VERSION
      )
    end

    def resolve_recording
      value = @config.recording_resolver&.call(@controller)
      return if value.blank?
      return value if value.respond_to?(:recordable_type)

      RecordingStudio::Recording.find_by(id: value)
    rescue StandardError
      nil
    end

    def recording_root(recording)
      return recording if recording.root?
      return recording.root_recording if recording.respond_to?(:root_recording)

      RecordingStudio::Recording.find_by(id: recording.root_recording_id)
    end

    def resolve_root(details)
      return details[:root_recording] if details[:root_recording].respond_to?(:id)
      return RecordingStudio::Recording.find_by(id: details[:root_recording_id]) if details[:root_recording_id].present?

      nil
    end

    def recording_enabled?(recording)
      type = recordable_type(recording)
      RecordingStudio.capability_enabled?(:viewable, for: type)
    end

    def recordable_type(recording)
      recording.recordable_type
    end

    def owned_root?(root)
      @config.root_ownership_policy.call(@controller, root)
    rescue StandardError
      false
    end

    def hashify(value)
      return if value.blank?
      return value if value.is_a?(Hash)

      {}
    end

    def clip(value, limit)
      return if value.nil?

      value.to_s[0, limit]
    end
  end
end
