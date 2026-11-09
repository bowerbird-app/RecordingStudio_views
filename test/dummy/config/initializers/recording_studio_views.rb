# frozen_string_literal: true

RecordingStudioViews.configure do |config|
  config.site_tracking_enabled = true
  config.tracking_access_action = :"recording_studio_views.view"

  config.consent_predicate = lambda do |request|
    page_path = request.params[:path].presence || request.path
    !page_path.to_s.start_with?("/no-consent")
  end

  config.skip_paths += [%r{\A/skipped(?:/|\z)}]

  account_id = Rails.application.credentials.dig(:maxmind, :account_id)
  license_key = Rails.application.credentials.dig(:maxmind, :license_key)
  if account_id.present? && license_key.present?
    config.geoip_database_path = Rails.root.join("db/GeoLite2-City.mmdb")
    config.maxmind_account_id = account_id
    config.maxmind_license_key = license_key
  end
end
