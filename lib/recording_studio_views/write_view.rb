# frozen_string_literal: true

module RecordingStudioViews
  class WriteView < RecordingStudio::Services::BaseService
    CAPTURED_KEYS = (
      %i[ip user_agent browser os os_version device_type country region city latitude longitude] +
      Configuration::UTM_KEYS
    ).freeze

    def initialize(event_id:, context:, path:, actor: nil, visitor_token_digest: nil, ip: nil, user_agent: nil,
                   captured: {})
      @event_id = event_id
      @context = context
      @path = path
      @actor = actor
      @visitor_token_digest = visitor_token_digest
      @captured = captured.to_h.symbolize_keys
      @captured[:ip] = ip unless ip.nil?
      @captured[:user_agent] = user_agent unless user_agent.nil?
      super()
    end

    def perform
      return failure("event_id is required", errors: [:invalid]) if @event_id.blank?
      return failure("context is required", errors: [:invalid]) if @context.nil? || @context.skipped?

      claim_and_insert
    rescue ActiveRecord::RecordNotUnique
      reconcile_duplicate
    rescue StandardError => e
      Instrumentation.record(:storage_failure, retryable: true)
      failure(e, errors: [:retryable])
    end

    private

    def claim_and_insert
      ViewReceipt.transaction do
        Storage.apply!(ViewLog)
        attributes = view_attributes
        RecordingStudioLogs.ensure_partition!(ViewLog, attributes[:occurred_at]) if Storage.partitioned?
        receipt = ViewReceipt.create!(
          id: @event_id,
          target_fingerprint: @context.fingerprint,
          accepted_at: Time.current
        )
        view = insert_view(attributes)
        success({ status: :accepted, view: view, receipt: receipt })
      end
    end

    def reconcile_duplicate
      receipt = ViewReceipt.find_by(id: @event_id)
      return failure("conflicting event", errors: [:conflict]) unless receipt
      return failure("conflicting event", errors: [:conflict]) unless receipt.target_fingerprint == @context.fingerprint

      success({ status: :duplicate, view: nil, receipt: receipt })
    end

    def insert_view(attributes)
      now = Time.current.utc
      row = attributes.merge(created_at: now, updated_at: now, arrived_at: now)
      ViewLog.insert_all!([row])
      ViewLog.where(id: attributes[:id]).first!
    end

    def view_attributes
      occurred_at = Time.current.utc
      {
        id: @event_id,
        occurred_at: occurred_at,
        root_recording_id: @context.root_recording_id,
        recording_id: @context.recording_id,
        resource_type: @context.resource_type,
        page_key: @context.page_key,
        path: PathNormalizer.call(@path) || "/",
        actor_type: actor_type,
        actor_id: actor_id,
        visitor_token_digest: @visitor_token_digest
      }.merge(request_columns)
    end

    def request_columns
      {
        ip: stored_ip,
        user_agent: stored_user_agent,
        browser: captured_value(:browser) || device[:browser],
        os: captured_value(:os) || device[:os],
        os_version: captured_value(:os_version) || device[:os_version],
        device_type: captured_value(:device_type) || device[:device_type],
        utm_source: stored_utm(:utm_source),
        utm_medium: stored_utm(:utm_medium),
        utm_term: stored_utm(:utm_term),
        utm_content: stored_utm(:utm_content),
        utm_campaign: stored_utm(:utm_campaign),
        country: captured_value(:country),
        region: captured_value(:region),
        city: captured_value(:city),
        latitude: captured_value(:latitude),
        longitude: captured_value(:longitude)
      }
    end

    def stored_ip
      return unless RecordingStudioViews.configuration.store_ip

      IpMask.call(@captured[:ip])
    end

    def stored_user_agent
      return if @captured[:user_agent].blank?

      @captured[:user_agent].to_s[0, Configuration::USER_AGENT_LIMIT]
    end

    def device
      @device ||= DeviceParser.call(stored_user_agent)
    end

    def stored_utm(key)
      UtmCapture.sanitize(captured_value(key))
    end

    def captured_value(key)
      return unless CAPTURED_KEYS.include?(key)

      @captured[key]
    end

    def actor_type
      return if @actor.nil?

      @actor.class.name.to_s[0, Configuration::ACTOR_TYPE_LIMIT]
    end

    def actor_id
      return if @actor.nil? || !@actor.respond_to?(:id)

      @actor.id.to_s[0, 64]
    end
  end
end
