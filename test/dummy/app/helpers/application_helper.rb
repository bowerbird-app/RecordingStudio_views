module ApplicationHelper
  include DummyLayoutHelper

  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    content_for(:title, title) if title.present?
    concat render(
      FlatPack::PageNav::Component.new(
        back_tooltip: back_label,
        secondary_anchor_href: back_url
      )
    )
  end

  def dummy_sidebar_pages
    recordings = RecordingStudio::Recording.where(recordable_type: "Page")
    recordings = recordings.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
    recordings.filter_map(&:recordable).sort_by { |page| page.title.to_s.downcase }
  end
end
