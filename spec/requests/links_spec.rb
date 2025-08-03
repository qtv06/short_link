# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Links", type: :request do
  before do
    Link.initialize_url_counter
  end

  describe "POST /encode" do
    subject { post "/encode", params: { original_url: url } }

    context "with valid URL" do
      let(:url) { "https://www.example.com" }

      it "creates a new shortened link and returns success" do
        expect { subject }.to change(Link, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to include("application/json")
      end

      it "returns the correct JSON structure" do
        subject

        link = Link.last
        expected_response = {
          "data" => {
            "id" => link.id,
            "original_url" => url,
            "short_code" => link.short_code,
            "shortened_url" => link.shortened_url,
            "created_at" => link.created_at.as_json
          }
        }

        expect(response.parsed_body).to eq(expected_response)
      end
    end

    context "with invalid URL" do
      let(:url) { "not-a-valid-url" }

      it "returns validation error for invalid URL format" do
        expected_response = {
          "errors" => {
            "resource" => "link",
            "details" => [ "Original url must be a valid URL" ]
          }
        }

        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq(expected_response)
      end

      context "with missing URL" do
        subject { post "/encode", params: {} }

        it "returns validation error for missing URL" do
          expected_response = {
            "errors" => {
              "resource" => "link",
              "details" => [ "Original url can't be blank" ]
            }
          }

          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body).to eq(expected_response)
        end
      end
    end
  end

  describe "GET /decode" do
    subject { get "/decode", params: { short_code: } }

    let!(:link) { Link.create_shortened_for("https://www.example.com") }

    context "with valid short code" do
      let(:short_code) { link.short_code }

      it "returns the link data" do
        subject

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")

        json_response = JSON.parse(response.body)
        expect(json_response["data"]["id"]).to eq(link.id)
        expect(json_response["data"]["original_url"]).to eq(link.original_url)
        expect(json_response["data"]["short_code"]).to eq(link.short_code)
      end

      it "caches the link data" do
        # First request should cache the link
        subject

        # Verify the link is cached
        cached_link = Rails.cache.read("link:#{link.short_code}")
        expect(cached_link).to be_present
        expect(cached_link.id).to eq(link.id)
      end
    end

    context "with invalid short code" do
      let(:short_code) { "invalid" }

      it "returns not found error" do
        subject

        expect(response).to have_http_status(:not_found)
      end

      context "with non-existent short code" do
        let(:short_code) { "abcd12" }

        it "returns not found error for non-existent short code" do
          subject

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe "GET /:short_code (show action)" do
    subject { get "/#{short_code}" }

    let!(:link) { Link.create_shortened_for("https://www.example.com") }

    context "with valid short code" do
      let(:short_code) { link.short_code }

      it "redirects to the original URL" do
        subject

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(link.original_url)
      end

      it "allows redirects to external hosts" do
        external_link = Link.create_shortened_for("https://www.external-site.com")
        get "/#{external_link.short_code}"

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to("https://www.external-site.com")
      end

      it "uses cached link data" do
        # Pre-cache the link
        Rails.cache.write("link:#{link.short_code}", link, expires_in: 12.hours)

        # Mock the database call to ensure cache is used
        expect(Link).not_to receive(:find_by_short_code!)

        subject

        expect(response).to have_http_status(:moved_permanently)
      end
    end

    context "with invalid short code" do
      let(:short_code) { "invalid_code" }

      it "returns not found error" do
        subject

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "caching behavior" do
    let!(:link) { Link.create_shortened_for("https://www.example.com") }

    it "caches link data for 12 hours" do
      expect(Rails.cache).to receive(:fetch)
        .with("link:#{link.short_code}", expires_in: 12.hours)
        .and_call_original

      get "/decode", params: { short_code: link.short_code }
    end

    it "serves subsequent requests from cache" do
      # First request - should hit database and cache
      get "/decode", params: { short_code: link.short_code }

      # Mock the Link model to ensure it's not called again
      expect(Link).not_to receive(:find_by_short_code!)

      # Second request - should use cache
      get "/decode", params: { short_code: link.short_code }

      expect(response).to have_http_status(:ok)
    end
  end
end
