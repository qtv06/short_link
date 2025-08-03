# frozen_string_literal: true

module Rescuable
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_unexpected_error
    rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found_error
  end

  private

    def handle_invalid_record_error(error)
      resource = error.record.class.model_name.element
      details = error.record.errors.full_messages
      render_error(error, details: { resource:, details: }, status: :unprocessable_content)
    end

    def handle_not_found_error(error)
      render_error(error, details: { message: error.message }, status: :not_found)
    end

    def handle_unexpected_error(error)
      log_error(error)
      render_error(error, details: { message: "An unexpected error occurred" }, status: :internal_server_error)
    end

    def render_error(error, details:, status: :internal_server_error)
      render json: { errors: details }, status:
    end

    def log_error(error)
      Rails.logger.error error
      Rails.logger.error error.backtrace
    end
end
