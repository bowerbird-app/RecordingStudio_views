# frozen_string_literal: true

require "digest"

module RecordingStudioViews
  PageContext = Data.define(
    :kind, :recording_id, :root_recording_id, :resource_type, :page_key, :version
  ) do
    def self.skipped
      new(
        kind: :skipped,
        recording_id: nil,
        root_recording_id: nil,
        resource_type: nil,
        page_key: nil,
        version: Configuration::CONTEXT_VERSION
      )
    end

    def skipped?
      kind == :skipped
    end

    def site?
      kind == :site
    end

    def fingerprint
      Digest::SHA256.hexdigest(
        [kind, recording_id, root_recording_id, resource_type, page_key].join(":")
      )
    end

    def token_payload
      {
        kind: kind.to_s,
        version: version,
        recording_id: recording_id,
        root_recording_id: root_recording_id,
        resource_type: resource_type,
        page_key: page_key
      }
    end
  end
end
