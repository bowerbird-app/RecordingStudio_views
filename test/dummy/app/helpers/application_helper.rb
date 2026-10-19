module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          url: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end

  def dummy_pages_shell(&block)
    render FlatPack::SidebarLayout::Component.new(storage_key: "dummy-pages") do |layout|
      layout.sidebar { render "pages/sidebar" }
      layout.main(&block)
    end
  end

  def dummy_sidebar_pages
    recordings = RecordingStudio::Recording.where(recordable_type: "Page")
    recordings = recordings.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
    recordings.filter_map(&:recordable).sort_by { |page| page.title.to_s.downcase }
  end
end
