class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  http_basic_authenticate_with(
    name:     ENV.fetch("APP_USERNAME", "capo"),
    password: ENV.fetch("APP_PASSWORD", "capo"),
    if:       -> { Rails.env.production? }
  )
end
