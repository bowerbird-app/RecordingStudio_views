class NoConsentController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  def show
    @page = Page.find(params[:id])
    @current_recording = RecordingStudio::Recording.find_by!(recordable_type: "Page", recordable_id: @page.id)
  end
end
