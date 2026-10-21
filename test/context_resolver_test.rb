# frozen_string_literal: true

require "test_helper"

class ContextResolverTest < Minitest::Test
  FakeRecording = Struct.new(:id, :root_recording_id, :recordable_type, :root, :root_recording, keyword_init: true) do
    def root?
      root
    end
  end

  FakeController = Struct.new(:request, :controller_path, :current_recording, :current_root_page, :current_site_page,
                              keyword_init: true)

  FakeRequest = Struct.new(:path, :env, keyword_init: true)

  def setup
    @previous = {
      skip_paths: RecordingStudioViews.configuration.skip_paths,
      excluded: RecordingStudioViews.configuration.excluded_controller_paths,
      consent: RecordingStudioViews.configuration.consent_predicate,
      recording: RecordingStudioViews.configuration.recording_resolver,
      root_page: RecordingStudioViews.configuration.root_page_resolver,
      site_page: RecordingStudioViews.configuration.site_page_resolver,
      ownership: RecordingStudioViews.configuration.root_ownership_policy,
      site_enabled: RecordingStudioViews.configuration.site_tracking_enabled,
      authorizer: RecordingStudioViews.configuration.page_view_authorizer
    }
  end

  def teardown
    config = RecordingStudioViews.configuration
    config.skip_paths = @previous[:skip_paths]
    config.excluded_controller_paths = @previous[:excluded]
    config.consent_predicate = @previous[:consent]
    config.recording_resolver = @previous[:recording]
    config.root_page_resolver = @previous[:root_page]
    config.site_page_resolver = @previous[:site_page]
    config.root_ownership_policy = @previous[:ownership]
    config.site_tracking_enabled = @previous[:site_enabled]
    config.page_view_authorizer = @previous[:authorizer]
  end

  def test_skip_paths_and_missing_consent_are_skipped
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    controller = FakeController.new(request: FakeRequest.new(path: "/up"), controller_path: "pages")
    assert RecordingStudioViews::ContextResolver.new(controller).call.skipped?

    RecordingStudioViews.configuration.consent_predicate = ->(*) { false }
    controller = FakeController.new(request: FakeRequest.new(path: "/pages/1"), controller_path: "pages")
    assert RecordingStudioViews::ContextResolver.new(controller).call.skipped?
  end

  def test_recording_context_when_enabled
    recording = FakeRecording.new(
      id: "rec-1",
      root_recording_id: "root-1",
      recordable_type: "Page",
      root: false,
      root_recording: FakeRecording.new(id: "root-1", root_recording_id: nil, recordable_type: "Workspace", root: true)
    )
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) { recording }
    RecordingStudioViews.configuration.root_ownership_policy = ->(*) { true }
    RecordingStudio.stub :capability_enabled?, ->(name, **kwargs) { name == :viewable && kwargs[:for] == "Page" } do
      controller = FakeController.new(request: FakeRequest.new(path: "/pages/1"), controller_path: "pages")
      context = RecordingStudioViews::ContextResolver.new(controller).call
      refute context.skipped?
      assert_equal :recording, context.kind
      assert_equal "rec-1", context.recording_id
      assert_equal "root-1", context.root_recording_id
    end
  end

  def test_root_and_site_pages
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) {}
    root = FakeRecording.new(id: "root-1", recordable_type: "Workspace", root: true)
    RecordingStudioViews.configuration.root_page_resolver = lambda { |*|
      { root_recording: root, page_key: "workspace.search", resource_type: "Workspace" }
    }
    RecordingStudioViews.configuration.root_ownership_policy = ->(*) { true }
    controller = FakeController.new(request: FakeRequest.new(path: "/search"), controller_path: "workspace_searches")
    context = RecordingStudioViews::ContextResolver.new(controller).call
    assert_equal :root, context.kind
    assert_equal "workspace.search", context.page_key

    RecordingStudioViews.configuration.root_page_resolver = ->(*) {}
    RecordingStudioViews.configuration.site_tracking_enabled = true
    RecordingStudioViews.configuration.site_page_resolver = lambda { |*|
      { page_key: "site.about", resource_type: "Site" }
    }
    controller = FakeController.new(request: FakeRequest.new(path: "/site/about"), controller_path: "site_pages")
    context = RecordingStudioViews::ContextResolver.new(controller).call
    assert context.site?
  end

  def test_assigned_page_key_is_used_when_no_recording_or_root
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) {}
    RecordingStudioViews.configuration.root_page_resolver = ->(*) {}
    RecordingStudioViews.configuration.site_tracking_enabled = false
    env = { RecordingStudioViews::PageView::REQUEST_KEY => "home" }
    controller = FakeController.new(
      request: FakeRequest.new(path: "/", env: env),
      controller_path: "home"
    )
    context = RecordingStudioViews::ContextResolver.new(controller).call
    assert context.page?
    assert_equal "home", context.page_key
    assert_nil context.recording_id
    assert_nil context.root_recording_id
  end

  def test_recording_context_wins_over_an_assigned_page_key
    recording = FakeRecording.new(
      id: "rec-1",
      root_recording_id: "root-1",
      recordable_type: "Page",
      root: false,
      root_recording: FakeRecording.new(id: "root-1", root_recording_id: nil, recordable_type: "Workspace", root: true)
    )
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) { recording }
    RecordingStudioViews.configuration.root_ownership_policy = ->(*) { true }
    env = { RecordingStudioViews::PageView::REQUEST_KEY => "home" }
    RecordingStudio.stub :capability_enabled?, ->(name, **kwargs) { name == :viewable && kwargs[:for] == "Page" } do
      controller = FakeController.new(
        request: FakeRequest.new(path: "/pages/1", env: env),
        controller_path: "pages"
      )
      context = RecordingStudioViews::ContextResolver.new(controller).call
      assert_equal :recording, context.kind
      refute context.page?
    end
  end

  def test_disabled_viewable_recording_does_not_fall_through
    recording = FakeRecording.new(
      id: "rec-1",
      root_recording_id: "root-1",
      recordable_type: "Folder",
      root: false,
      root_recording: FakeRecording.new(id: "root-1", recordable_type: "Workspace", root: true)
    )
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) { recording }
    RecordingStudioViews.configuration.root_page_resolver = lambda { |*|
      { root_recording: recording.root_recording, page_key: "workspace.search", resource_type: "Workspace" }
    }
    RecordingStudioViews.configuration.site_tracking_enabled = true
    RecordingStudioViews.configuration.site_page_resolver = lambda { |*|
      { page_key: "site.home", resource_type: "Site" }
    }
    RecordingStudioViews.configuration.root_ownership_policy = ->(*) { true }
    RecordingStudio.stub :capability_enabled?, ->(*) { false } do
      controller = FakeController.new(request: FakeRequest.new(path: "/folders/1"), controller_path: "folders")
      context = RecordingStudioViews::ContextResolver.new(controller).call
      assert context.skipped?
    end
  end

  def test_root_ownership_policy_skips_a_foreign_root
    recording = FakeRecording.new(
      id: "rec-1",
      root_recording_id: "root-2",
      recordable_type: "Page",
      root: false,
      root_recording: FakeRecording.new(id: "root-2", recordable_type: "Workspace", root: true)
    )
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) { recording }
    RecordingStudioViews.configuration.root_ownership_policy = lambda { |_controller, root|
      root.id == "root-1"
    }
    RecordingStudio.stub :capability_enabled?, ->(name, **kwargs) { name == :viewable && kwargs[:for] == "Page" } do
      controller = FakeController.new(request: FakeRequest.new(path: "/pages/1"), controller_path: "pages")
      assert RecordingStudioViews::ContextResolver.new(controller).call.skipped?
    end
  end

  def test_site_pages_stay_skipped_when_disabled
    RecordingStudioViews.configuration.consent_predicate = ->(*) { true }
    RecordingStudioViews.configuration.recording_resolver = ->(*) {}
    RecordingStudioViews.configuration.root_page_resolver = ->(*) {}
    RecordingStudioViews.configuration.site_tracking_enabled = false
    RecordingStudioViews.configuration.site_page_resolver = lambda { |*|
      { page_key: "site.about", resource_type: "Site" }
    }
    controller = FakeController.new(request: FakeRequest.new(path: "/site/about"), controller_path: "site_pages")
    assert RecordingStudioViews::ContextResolver.new(controller).call.skipped?
  end
end
