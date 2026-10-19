# frozen_string_literal: true

module RecordingStudioViews
  # Opaque visitor id supplied by the host.
  #
  # Views does not mint a cookie and does not read RecordingStudio root
  # switchable. The usual host source is that gem's anonymous device key,
  # passed through +visitor_id_resolver+.
  module VisitorId
    def self.resolve(controller)
      return if controller.nil?

      resolver = RecordingStudioViews.configuration.visitor_id_resolver
      return if resolver.nil?

      value = resolver.call(controller)
      return if value.nil?

      text = value.to_s
      text unless text.empty?
    end
  end
end
