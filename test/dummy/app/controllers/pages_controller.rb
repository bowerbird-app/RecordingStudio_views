class PagesController < ApplicationController
  before_action :set_page, only: %i[show edit update destroy]

  def index
  end

  def show
    @current_recording = recording_for(@page)
    return unless authorize_viewable_recording!(@current_recording)
  end

  def new
    @page = Page.new
  end

  def create
    @page = Page.new(page_params)
    root_recording = workspace_root_recording

    unless root_recording
      flash.now[:alert] = "Pick a workspace first, then try again."
      render :new, status: :unprocessable_entity
      return
    end

    if @page.title.blank?
      flash.now[:alert] = "Give the page a title."
      render :new, status: :unprocessable_entity
      return
    end

    @page.save!
    RecordingStudio.record!(
      action: "created",
      recordable: @page,
      root_recording: root_recording,
      parent_recording: root_recording
    )
    redirect_to page_path(@page)
  end

  def edit
  end

  def update
    recording = recording_for(@page)
    title = page_params[:title].to_s.strip

    if title.blank?
      flash.now[:alert] = "Give the page a title."
      render :edit, status: :unprocessable_entity
      return
    end

    updated = recording.revise(recording) { |recordable| recordable.title = title }
    redirect_to page_path(updated.recordable)
  end

  def destroy
    recording = recording_for(@page)
    RecordingStudio::Recording.transaction do
      recording.events.delete_all
      recording.destroy!
    end
    redirect_to pages_path, status: :see_other
  end

  private

  def set_page
    @page = Page.find(params[:id])
  end

  def page_params
    params.require(:page).permit(:title)
  end

  def recording_for(page)
    RecordingStudio::Recording.find_by!(recordable_type: "Page", recordable_id: page.id)
  end

  def workspace_root_recording
    root = current_root_recording
    return root if root&.recordable_type == "Workspace"

    studio = Workspace.find_by(name: "Studio Workspace") || Workspace.order(:name).first
    return unless studio

    RecordingStudio.root_recording_for(studio)
  end
end
