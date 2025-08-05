# frozen_string_literal: true

require "rails_helper"

RSpec.describe Link, type: :model do
  let(:valid_url) { "https://www.example.com" }
  let(:invalid_url) { "not-a-url" }

  describe "validations" do
    subject { described_class.new(original_url: valid_url, short_code: "abc123") }

    describe "presence validations" do
      it "requires original_url to be present" do
        link = described_class.new(short_code: "abc123")
        expect(link).not_to be_valid
        expect(link.errors[:original_url]).to include("can't be blank")
      end

      it "requires short_code to be present" do
        link = described_class.new(original_url: valid_url)
        expect(link).not_to be_valid
        expect(link.errors[:short_code]).to include("can't be blank")
      end
    end

    describe "original_url format validation" do
      it "accepts valid URLs" do
        valid_urls = [
          "https://www.example.com",
          "http://example.com",
          "https://subdomain.example.com/path?query=value",
          "https://example.com:8080/path"
        ]

        valid_urls.each do |url|
          link = described_class.new(original_url: url, short_code: "abc123")
          expect(link).to be_valid, "Expected #{url} to be valid"
        end
      end

      it "rejects invalid URLs" do
        invalid_urls = [
          "not-a-url",
          "example.com",
          "www.example"
        ]

        invalid_urls.each do |url|
          link = described_class.new(original_url: url, short_code: "abc123")
          expect(link).not_to be_valid, "Expected #{url} to be invalid"
          expect(link.errors[:original_url]).to include("must be a valid URL")
        end
      end

      it "rejects javascript URLs for security" do
        link = described_class.new(original_url: 'javascript:alert("xss")', short_code: "abc123")
        expect(link).not_to be_valid
      end

      it "allows blank original_url to skip format validation" do
        link = described_class.new(original_url: "", short_code: "abc123")
        link.valid?
        expect(link.errors[:original_url]).to include("can't be blank")
        expect(link.errors[:original_url]).not_to include("must be a valid URL")
      end
    end

    describe "short_code length validation" do
      it "rejects short codes that are too short" do
        link = described_class.new(original_url: valid_url, short_code: "abc12")
        expect(link).not_to be_valid
        expect(link.errors[:short_code]).to include("is the wrong length (should be 6 characters)")
      end

      it "rejects short codes that are too long" do
        link = described_class.new(original_url: valid_url, short_code: "abc1234")
        expect(link).not_to be_valid
        expect(link.errors[:short_code]).to include("is the wrong length (should be 6 characters)")
      end
    end
  end

  describe ".create_shortened_for" do
    let(:original_url) { "https://www.example.com" }

    before do
      described_class.initialize_url_counter
    end

    it "creates a new link with a short code" do
      link = described_class.create_shortened_for(original_url)

      expect(link).to be_persisted
      expect(link.original_url).to eq(original_url)
      expect(link.short_code).to be_present
      expect(link.short_code.length).to eq(6)
    end

    it "generates unique short codes for different URLs" do
      link1 = described_class.create_shortened_for("https://www.example1.com")
      link2 = described_class.create_shortened_for("https://www.example2.com")

      expect(link1.short_code).not_to eq(link2.short_code)
    end

    it "generates unique short codes for the same URL" do
      link1 = described_class.create_shortened_for(original_url)
      link2 = described_class.create_shortened_for(original_url)

      expect(link1.short_code).not_to eq(link2.short_code)
    end

    it "increments the URL counter" do
      initial_counter = Rails.cache.read(described_class::URL_COUNTER_KEY, raw: true).to_i
      described_class.create_shortened_for(original_url)

      expect(Rails.cache.read(described_class::URL_COUNTER_KEY, raw: true).to_i).to eq(initial_counter + 1)
    end

    it "uses Base62 encoding for the short code" do
      allow(described_class).to receive(:increment_url_counter).and_return(1_000_000_001)
      expected_code = Base62.encode(1_000_000_001)

      link = described_class.create_shortened_for(original_url)
      expect(link.short_code).to eq(expected_code)
    end

    context "when there is a collision (ActiveRecord::RecordNotUnique)" do
      it "retries until successful" do
        # Mock the first save to raise an exception, then succeed
        link_instance = described_class.new(original_url:)
        allow(described_class).to receive(:new).and_return(link_instance)

        call_count = 0
        allow(link_instance).to receive(:save!) do
          call_count += 1
          if call_count == 1
            raise ActiveRecord::RecordNotUnique.new("Duplicate entry")
          else
            true
          end
        end

        expect(Rails.logger).to receive(:error).with(/Failed to create unique short code/)

        link = described_class.create_shortened_for(original_url)
        expect(link).to eq(link_instance)
      end
    end
  end

  describe ".increment_url_counter" do
    before do
      described_class.initialize_url_counter
    end

    it "increments the counter in cache" do
      initial_value = Rails.cache.read(described_class::URL_COUNTER_KEY, raw: true).to_i
      result = described_class.increment_url_counter

      expect(result).to eq(initial_value + 1)
      expect(Rails.cache.read(described_class::URL_COUNTER_KEY, raw: true).to_i).to eq(initial_value + 1)
    end

    it "returns the incremented value" do
      result = described_class.increment_url_counter

      expect(result).to eq(described_class::INITIAL_URL_COUNTER + 1)
    end
  end

  describe ".initialize_url_counter" do
    before { Rails.cache.clear }

    it "sets the initial counter value when cache is empty" do
      expect(Rails.cache.exist?(described_class::URL_COUNTER_KEY)).to be false

      described_class.initialize_url_counter

      expect(Rails.cache.read(described_class::URL_COUNTER_KEY, raw: true).to_i).to eq(described_class::INITIAL_URL_COUNTER)
    end
  end

  describe "#shortened_url" do
    let(:link) { described_class.new(original_url: valid_url, short_code: "abc123") }

    it "returns the shortened URL using Rails routes" do
      expect(link.shortened_url).to eq("http://localhost:3000/abc123")
    end
  end
end
