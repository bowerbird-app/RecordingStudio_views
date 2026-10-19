# frozen_string_literal: true

module RecordingStudioViews
  module BotFilter
    PATTERN = /
      bot|crawler|spider|crawling|preview|slurp|fetcher|
      facebookexternalhit|whatsapp|telegram|discord|slackbot|
      googlebot|bingbot|yandex|baiduspider|duckduckbot|
      ahrefs|semrush|mj12bot|dotbot
    /ix

    def self.bot?(user_agent)
      return false if user_agent.blank?

      PATTERN.match?(user_agent)
    end
  end
end
