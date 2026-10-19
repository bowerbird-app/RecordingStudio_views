# frozen_string_literal: true

RecordingStudioViews.configure do |config|
  # Opaque anonymous device key from root_switchable. Views does not read that gem.
  config.visitor_id_resolver = lambda do |controller|
    next unless controller.respond_to?(:current_root_device_key)

    controller.current_root_device_key
  end

  config.user_id_resolver = lambda do |controller|
    next unless controller.respond_to?(:current_user)

    controller.current_user&.id
  end

  config.root_recording_id_resolver = lambda do |controller|
    next unless controller.respond_to?(:current_root_recording)

    controller.current_root_recording&.id
  end
end
