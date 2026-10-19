# frozen_string_literal: true

RecordingStudioViews.configure do |config|
  # Opaque visitor id from the host. Views does not set a cookie.
  # config.visitor_id_resolver = ->(controller) { controller.current_root_device_key }
  # config.user_id_resolver = ->(controller) { controller.current_user&.id }
  # config.root_recording_id_resolver = ->(controller) { controller.current_root_recording&.id }

  # Set your API key (recommended to use ENV or Rails credentials)
  # config.api_key = ENV["RECORDING_STUDIO_VIEWS_API_KEY"]

  # Enable optional feature X
  # config.enable_feature_x = false

  # Timeout in seconds for external calls
  # config.timeout = 5
end
