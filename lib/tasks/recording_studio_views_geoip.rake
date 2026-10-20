# frozen_string_literal: true

namespace :recording_studio_views do
  namespace :geoip do
    desc "Download or refresh MaxMind GeoLite2 City into config.geoip_database_path"
    task update: :environment do
      RecordingStudioViews::GeoipUpdater.call(force: ENV["FORCE"] == "1")
    rescue RecordingStudioViews::GeoipUpdater::Error => e
      abort e.message
    end
  end
end
