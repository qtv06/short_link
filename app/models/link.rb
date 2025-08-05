# frozen_string_literal: true

class Link < ApplicationRecord
  # Initial value for the URL counter, starting from 1 billion will make the short url more readable
  INITIAL_URL_COUNTER = 1_000_000_000
  URL_COUNTER_KEY = "url_counter"

  validates :original_url, presence: true
  validates :original_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :short_code, presence: true, length: { is: 6 }

  class << self
    def create_shortened_for(original_url)
      link = new(original_url:)

      begin
        counter = increment_url_counter
        link.short_code = Base62.encode(counter)
        link.save!
        link
      rescue ActiveRecord::RecordNotUnique => e
        Rails.logger.error("Failed to create unique short code: #{e.message}")
        retry
      end
    end

    def increment_url_counter
      Rails.cache.increment(URL_COUNTER_KEY)
    end

    def initialize_url_counter
      Rails.cache.write(URL_COUNTER_KEY, INITIAL_URL_COUNTER, raw: true) unless Rails.cache.exist?(URL_COUNTER_KEY)
    end
  end

  def shortened_url
    Rails.application.routes.url_helpers.short_link_url(short_code)
  end
end
