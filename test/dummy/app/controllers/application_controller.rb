class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport

  PAGE_VIEW_ACTION = :"recording_studio_views.view"

  SITE_PAGE_KEYS = {
    "devise/sessions" => "site.sign_in",
    "devise/registrations" => "site.sign_up",
    "site_pages" => "site.about"
  }.freeze
  SITE_PAGE_PATHS = {
    "/users/sign_in" => "site.sign_in",
    "/users/sign_up" => "site.sign_up",
    "/site/about" => "site.about"
  }.freeze

  allow_browser versions: :modern

  stale_when_importmap_changes

  layout :application_layout

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_actor

  helper DummyLayoutHelper
  helper RecordingStudio::LayoutHelper
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
    page_key = SITE_PAGE_PATHS[request.path] || SITE_PAGE_KEYS[controller_path]
    return unless page_key

    { page_key: page_key, resource_type: "Site" }
  end

  def current_actor
    Current.actor
  end

  private

  def application_layout
    devise_controller? ? "application" : "flat_pack_sidebar"
  end

  def set_current_actor
    Current.actor = current_user
  end

  def authorize_viewable_recording!(recording)
    allowed = RecordingStudioAccessible.authorized_action?(
      actor: Current.actor,
      action: PAGE_VIEW_ACTION,
      recording: recording
    )
    return true if allowed

    head :forbidden
    false
  end
end
