class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]
  include RecordingStudio::Capabilities::Viewable.to
  RecordingStudio.enable_capability(:action_audiences, on: self) if defined?(RecordingStudioAccessible)
end
