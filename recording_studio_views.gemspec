# frozen_string_literal: true

require_relative "lib/recording_studio_views/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_views"
  spec.version     = RecordingStudioViews::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_views"
  spec.summary     = "Page-view collection for Recording Studio"
  spec.description = "Records host page views into Recording Studio Logs. " \
                     "Installing the gem does not start tracking. Built as a Recording Studio addon on Rails 8.1."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_views"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_views/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "device_detector"
  spec.add_dependency "maxmind-db"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_logs", ">= 0.4.0", "< 1.0"
end
