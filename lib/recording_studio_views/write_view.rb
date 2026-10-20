# frozen_string_literal: true

module RecordingStudioViews
  class WriteView < RecordingStudio::Services::BaseService
    def initialize(event_id:, context:, path:, actor: nil, visitor_token_digest: nil, ip: nil, user_agent: nil)
      @event_id = event_id
      @context = context
      @path = path
      @actor = actor
      @visitor_token_digest = visitor_token_digest
      @ip = ip
      @user_agent = user_agent
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
        visitor_token_digest: @visitor_token_digest,
        ip: stored_ip,
        user_agent: stored_user_agent
      }
    end

    def stored_ip
      return unless RecordingStudioViews.configuration.store_ip

      IpMask.call(@ip)
    end

    def stored_user_agent
      return if @user_agent.blank?

      @user_agent.to_s[0, Configuration::USER_AGENT_LIMIT]
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
