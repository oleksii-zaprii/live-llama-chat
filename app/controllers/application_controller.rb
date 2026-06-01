class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_la_user

  def current_la_user
    @current_la_user ||= User.find_by(id: session[:la_user_id])
  end

  def require_la_authentication
    unless current_la_user
      redirect_to new_la_session_path, alert: "Please sign in to access the Loan Advocate portal."
    end
  end
end
