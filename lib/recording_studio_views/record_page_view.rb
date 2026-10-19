# frozen_string_literal: true

module RecordingStudioViews
  class RecordPageView < RecordingStudio::Services::BaseService
    def initialize(controller: nil, **attributes)
      @controller = controller
      @attributes = attributes
      super()
    end

    def perform
      attributes = page_view_attributes
      return failure("path is required") if attributes[:path].blank?

      success(PageView.create!(attributes))
    end

    private

    def page_view_attributes
      context = RequestContext.new(@controller)
      identity_attributes(context).merge(request_attributes(context))
    end

    def identity_attributes(context)
      {
        resource_type: resource_type,
        recording_id: attribute(:recording_id),
        root_recording_id: chosen(:root_recording_id, context.root_recording_id),
        user_id: chosen(:user_id, context.user_id),
        visitor_id: visitor_id_for(context)
      }
    end

    def request_attributes(context)
      {
        path: chosen(:path, context.path),
        occurred_at: attribute(:occurred_at) || Time.current,
        referrer: chosen(:referrer, context.referrer),
        query_params: query_params_for(context)
      }
    end

    def resource_type
      given = supplied?(:resource_type) ? attribute(:resource_type) : "Page"
      given.presence || "Page"
    end

    def visitor_id_for(context)
      return VisitorIdText.present(attribute(:visitor_id)) if supplied?(:visitor_id)

      context.visitor_id
    end

    def query_params_for(context)
      return QueryParams.extract(attribute(:query_params)) if supplied?(:query_params)

      context.query_params
    end

    def chosen(name, fallback)
      supplied?(name) ? attribute(name) : fallback
    end

    def supplied?(name)
      @attributes.key?(name) || @attributes.key?(name.to_s)
    end

    def attribute(name)
      return @attributes[name] if @attributes.key?(name)

      @attributes[name.to_s]
    end
  end

  # Reads the request and host resolvers. Does not write a visitor cookie.
  class RequestContext
    def initialize(controller)
      @controller = controller
    end

    def path
      request&.path
    end

    def referrer
      request&.referrer
    end

    def query_params
      QueryParams.extract(request&.query_parameters || {})
    end

    def user_id
      resolve(:user_id_resolver)
    end

    def visitor_id
      VisitorId.resolve(@controller)
    end

    def root_recording_id
      resolve(:root_recording_id_resolver)
    end

    private

    def request
      return unless @controller.respond_to?(:request)

      @controller.request
    end

    def resolve(config_name)
      return if @controller.nil?

      resolver = RecordingStudioViews.configuration.public_send(config_name)
      return if resolver.nil?

      resolver.call(@controller).presence
    end
  end

  module VisitorIdText
    def self.present(value)
      return if value.nil?

      text = value.to_s
      text unless text.empty?
    end
  end
end
