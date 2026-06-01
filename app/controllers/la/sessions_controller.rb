class La::SessionsController < ApplicationController
  layout "la"
  before_action :redirect_if_authenticated, only: %i[new create]

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user&.authenticate(params[:password])
      session[:la_user_id] = user.id
      user.update_column(:availability_status, "online")
      redirect_to la_dashboard_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if (user = current_la_user)
      user.update_column(:availability_status, "offline")
    end
    session.delete(:la_user_id)
    redirect_to new_la_session_path, notice: "You have been signed out."
  end

  private

  def redirect_if_authenticated
    redirect_to la_dashboard_path if current_la_user
  end
end
