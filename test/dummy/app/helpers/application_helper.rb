module ApplicationHelper
  include DummyLayoutHelper

  def dummy_sidebar_pages
    recordings = RecordingStudio::Recording.where(recordable_type: "Page")
    recordings = recordings.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
    recordings.filter_map(&:recordable).sort_by { |page| page.title.to_s.downcase }
  end
end
