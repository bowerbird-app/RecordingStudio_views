class WorkspaceSearchesController < ApplicationController
  def show
    workspace = Workspace.find(params[:id])
    @root_page_recording = RecordingStudio.root_recording_for(workspace)
  end
end
