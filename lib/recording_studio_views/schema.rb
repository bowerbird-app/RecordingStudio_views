# frozen_string_literal: true

module RecordingStudioViews
  module Schema
    VIEW_LOGS = :recording_studio_views_view_logs
    RECEIPTS = :recording_studio_views_view_receipts
    SUMMARIES = :recording_studio_views_daily_view_summaries

    module_function

    def create_view_logs!(partitioned:, connection: ActiveRecord::Base.connection)
      if partitioned
        RecordingStudioLogs::Schema.partitioned_log(
          VIEW_LOGS, timestamp_column: :occurred_at, connection: connection
        ) { |table| view_log_columns(table) }
      else
        connection.create_table(VIEW_LOGS, id: :uuid) do |table|
          table.datetime :occurred_at, null: false
          table.datetime :arrived_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
          view_log_columns(table)
        end
      end
      RecordingStudioLogs::Schema.root_and_time_index(
        VIEW_LOGS, root_column: :root_recording_id, timestamp_column: :occurred_at, connection: connection
      )
    end

    def create_receipts!(connection: ActiveRecord::Base.connection)
      connection.create_table(RECEIPTS, id: :uuid) do |table|
        table.string :target_fingerprint, null: false, limit: 64
        table.datetime :accepted_at, null: false
        table.timestamps
      end
      connection.add_index RECEIPTS, :accepted_at, name: "index_rs_views_view_receipts_on_accepted_at"
    end

    def create_summaries!(connection: ActiveRecord::Base.connection)
      connection.create_table(SUMMARIES, id: :uuid) do |table|
        table.date :day, null: false
        table.uuid :root_recording_id
        table.uuid :recording_id
        table.string :resource_type, limit: Configuration::RESOURCE_TYPE_LIMIT
        table.string :page_key, null: false, limit: Configuration::PAGE_KEY_LIMIT
        table.integer :views, null: false, default: 0
        table.timestamps
      end
      RecordingStudioLogs::Schema.summary_index(
        SUMMARIES,
        %i[day root_recording_id recording_id resource_type page_key],
        name: "index_rs_views_daily_view_summaries_identity",
        connection: connection
      )
    end

    def add_kind_column!(connection: ActiveRecord::Base.connection)
      return unless connection.data_source_exists?(VIEW_LOGS)
      return if connection.column_exists?(VIEW_LOGS, :kind)

      connection.add_column VIEW_LOGS, :kind, :string, limit: NamedPage::KIND_LIMIT
    end

    def add_request_columns!(connection: ActiveRecord::Base.connection)
      return unless connection.data_source_exists?(VIEW_LOGS)

      request_string_columns.each do |name, limit|
        add_string_column(connection, name, limit)
      end
      add_decimal_column(connection, :latitude)
      add_decimal_column(connection, :longitude)
    end

    def request_string_columns
      {
        ip: Configuration::IP_LIMIT,
        user_agent: Configuration::USER_AGENT_LIMIT,
        browser: Configuration::DEVICE_FIELD_LIMIT,
        os: Configuration::DEVICE_FIELD_LIMIT,
        device_type: Configuration::DEVICE_FIELD_LIMIT,
        os_version: Configuration::DEVICE_FIELD_LIMIT,
        utm_source: Configuration::UTM_LIMIT,
        utm_medium: Configuration::UTM_LIMIT,
        utm_term: Configuration::UTM_LIMIT,
        utm_content: Configuration::UTM_LIMIT,
        utm_campaign: Configuration::UTM_LIMIT,
        country: Configuration::GEO_NAME_LIMIT,
        region: Configuration::GEO_NAME_LIMIT,
        city: Configuration::GEO_NAME_LIMIT
      }
    end

    def add_string_column(connection, name, limit)
      return if connection.column_exists?(VIEW_LOGS, name)

      connection.add_column VIEW_LOGS, name, :string, limit: limit
    end

    def add_decimal_column(connection, name)
      return if connection.column_exists?(VIEW_LOGS, name)

      connection.add_column VIEW_LOGS, name, :decimal, precision: 10, scale: 6
    end

    def view_log_columns(table)
      table.uuid :root_recording_id
      table.uuid :recording_id
      table.string :resource_type, limit: Configuration::RESOURCE_TYPE_LIMIT
      table.string :page_key, null: false, limit: Configuration::PAGE_KEY_LIMIT
      table.string :kind, limit: NamedPage::KIND_LIMIT
      table.string :path, null: false, limit: Configuration::PATH_LIMIT
      table.string :actor_type, limit: Configuration::ACTOR_TYPE_LIMIT
      table.string :actor_id, limit: 64
      table.string :visitor_token_digest, limit: 64
      request_string_columns.each { |name, limit| table.string name, limit: limit }
      table.decimal :latitude, precision: 10, scale: 6
      table.decimal :longitude, precision: 10, scale: 6
      table.timestamps
    end
  end
end
