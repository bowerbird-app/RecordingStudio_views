# frozen_string_literal: true

RecordingStudioViews.configure do |config|
  config.site_tracking_enabled = true

  config.tracking_access_policy = lambda do |_request, context, actor|
    next :deny if context.skipped?
    next :allow if context.site?
    next :allow if actor.present?

    studio = Workspace.find_by(name: "Studio Workspace")
    next :deny unless studio && context.kind == :recording

    root = RecordingStudio.root_recording_for(studio)
    context.root_recording_id.to_s == root.id.to_s ? :allow : :deny
  end

  config.consent_predicate = lambda do |request|
    page_path = request.params[:path].presence || request.path
    !page_path.to_s.start_with?("/no-consent")
  end

  config.skip_paths += [%r{\A/skipped(?:/|\z)}]
end
