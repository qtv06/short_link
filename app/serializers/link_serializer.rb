# frozen_string_literal: true

class LinkSerializer < ActiveModel::Serializer
  attributes :id, :original_url, :short_code, :shortened_url, :created_at
end
