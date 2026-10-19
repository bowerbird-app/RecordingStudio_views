class FoldersController < ApplicationController
  def show
    @folder = Folder.find(params[:id])
    @current_recording = RecordingStudio::Recording.find_by!(recordable_type: "Folder", recordable_id: @folder.id)
  end
end
