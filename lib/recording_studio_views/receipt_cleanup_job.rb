# frozen_string_literal: true

module RecordingStudioViews
  class ReceiptCleanupJob < ActiveJob::Base
    queue_as :default

    def perform(older_than: Configuration::DEDUP_WINDOW)
      cutoff = Time.current.utc - older_than
      ViewReceipt.where("accepted_at < ?", cutoff).delete_all
    end
  end
end
