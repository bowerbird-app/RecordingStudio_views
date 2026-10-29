module ApplicationHelper
  include DummyLayoutHelper

  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    content_for(:title, title) if title.present?
    return if back_url.blank?

    concat render(FlatPack::PageNav::Component.new(round: true, style: :default)) { |nav|
      nav.with_back(href: back_url, tooltip: back_label)
    }
  end

  def dummy_sidebar_pages
    recordings = RecordingStudio::Recording.where(recordable_type: "Page")
    recordings = recordings.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
    recordings.filter_map(&:recordable).sort_by { |page| page.title.to_s.downcase }
  end
end
