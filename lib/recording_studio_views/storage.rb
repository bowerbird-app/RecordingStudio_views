# frozen_string_literal: true

module RecordingStudioViews
  module Storage
    TABLE = "recording_studio_views_view_logs"

    module_function

    def partitioned?
      return false unless table_exists?

      inspection = RecordingStudioLogs::Schema.inspect_table(TABLE)
      inspection.partitioned
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      false
    end

    def table_exists?
      ActiveRecord::Base.connection.data_source_exists?(TABLE)
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      false
    end

    def apply!(model = ViewLog)
      return unless table_exists?

      model.primary_key = partitioned? ? %i[id occurred_at] : "id"
    end

    def partition_interval
      partitioned? ? :monthly : nil
    end
  end
end
