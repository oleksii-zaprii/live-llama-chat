module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_la_user

    def connect
      user_id = request.session[:la_user_id]
      self.current_la_user = User.find_by(id: user_id) if user_id
    end
  end
end
