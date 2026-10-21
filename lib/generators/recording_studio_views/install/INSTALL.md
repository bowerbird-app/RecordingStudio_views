RecordingStudioViews has been installed.

The install generator does not mount the engine or edit layouts.

Add `<%= recording_studio_track_views %>` to the shared layout body (not the head), mount the engine at `/recording_studio_views`, pin the collector, and enable `RecordingStudio::Capabilities::Viewable.to` on recordable types you want tracked. Named pages opt in with `recording_studio_track_page_view("home")`.
