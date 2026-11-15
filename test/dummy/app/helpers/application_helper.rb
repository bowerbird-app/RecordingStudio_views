module ApplicationHelper
  include DummyLayoutHelper

  def dummy_sidebar_pages
    recordings = RecordingStudio::Recording.kept.where(recordable_type: "Page")
    recordings.filter_map(&:recordable).sort_by { |page| page.title.to_s.downcase }
  end
end
