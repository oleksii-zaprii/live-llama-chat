class LaQueueChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_la_user

    stream_from "la_queue"
    Rails.logger.info "[LaQueueChannel] User ##{current_la_user.id} subscribed to la_queue"
  end

  def unsubscribed
    Rails.logger.info "[LaQueueChannel] User unsubscribed from la_queue"
  end
end
