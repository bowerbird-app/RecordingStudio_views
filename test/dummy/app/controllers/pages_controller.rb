class PagesController < ApplicationController
  def show
    @page = Page.find(params[:id])
    @current_recording = recording_for(@page)
  end

  private

  def recording_for(page)
    RecordingStudio::Recording.find_by!(recordable_type: "Page", recordable_id: page.id)
  end
end
