# frozen_string_literal: true

require "test_helper"

class StorageTest < Minitest::Test
  FakeInspection = Struct.new(:partitioned)

  def test_ordinary_table_registers_nil_interval
    RecordingStudioViews::Storage.stub :table_exists?, true do
      RecordingStudioLogs::Schema.stub :inspect_table, FakeInspection.new(false) do
        refute RecordingStudioViews::Storage.partitioned?
        assert_nil RecordingStudioViews::Storage.partition_interval
      end
    end
  end

  def test_partitioned_table_registers_monthly
    RecordingStudioViews::Storage.stub :table_exists?, true do
      RecordingStudioLogs::Schema.stub :inspect_table, FakeInspection.new(true) do
        assert RecordingStudioViews::Storage.partitioned?
        assert_equal :monthly, RecordingStudioViews::Storage.partition_interval
      end
    end
  end

  def test_missing_table_is_not_partitioned
    RecordingStudioViews::Storage.stub :table_exists?, false do
      refute RecordingStudioViews::Storage.partitioned?
      assert_nil RecordingStudioViews::Storage.partition_interval
    end
  end
end
