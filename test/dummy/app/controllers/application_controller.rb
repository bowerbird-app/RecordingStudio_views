class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport
  include RecordingStudio::UsesDefaultLayout

  allow_browser versions: :modern

  stale_when_importmap_changes

  layout :application_layout

  before_action :authenticate_user!
  before_action :set_current_actor

  helper_method :current_recording, :current_root_page, :current_site_page, :current_actor

  def current_recording
    @current_recording
  end

  def current_root_page
    return unless @root_page_recording

    {
      root_recording: @root_page_recording,
      page_key: "workspace.search",
      resource_type: "Workspace"
    }
  end

  def current_site_page
    return unless @site_page

    { page_key: "site.about", resource_type: "Site" }
  end

  def current_actor
    Current.actor
  end

  private

  def application_layout
    devise_controller? ? "application" : "recording_studio/default_layout"
  end

  def set_current_actor
    Current.actor = current_user
  end
end
