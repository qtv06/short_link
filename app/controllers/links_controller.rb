# frozen_string_literal: true

class LinksController < ApplicationController
  before_action :set_link, only: %i[decode show]

  rate_limit to: 20, within: 5.minutes, only: :encode

  def encode
    link = Link.create_shortened_for(params[:original_url])
    render json: link, serializer: LinkSerializer, root: :data, status: :created
  end

  def decode
    render json: @link, serializer: LinkSerializer, root: :data, status: :ok
  end

  def show
    redirect_to @link.original_url, status: :moved_permanently, allow_other_host: true
  end

  def welcome; end

  def hello; end

  private

    def set_link
      @link = Rails.cache.fetch("link:#{params[:short_code]}", expires_in: 12.hours) do
        Link.find_by_short_code!(params[:short_code])
      end
    end
end
