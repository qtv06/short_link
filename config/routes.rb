# frozen_string_literal: true

Rails.application.routes.draw do
  post "encode", to: "links#encode"
  get "decode", to: "links#decode"
  get ":short_code", to: "links#show", as: :short_link
  get "up" => "rails/health#show", as: :rails_health_check
end
