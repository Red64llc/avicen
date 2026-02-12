class ApplicationController < ActionController::Base
  include Authentication
  include SetTimezone
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Check if the request is a Turbo Frame request
  # Turbo Frame requests include a "Turbo-Frame" header with the frame ID
  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end
end
