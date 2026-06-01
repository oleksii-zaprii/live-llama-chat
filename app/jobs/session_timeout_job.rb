class SessionTimeoutJob < ApplicationJob
  queue_as :default

  def perform
    timed_out = Conversation.timed_out

    timed_out.find_each do |conversation|
      Rails.logger.info "[SessionTimeoutJob] Timing out conversation ##{conversation.id} (status: #{conversation.status})"

      # Notify the customer widget
      ActionCable.server.broadcast(
        "conversation_#{conversation.session_token}",
        {
          type: "session_timeout",
          message: "This chat session has expired due to inactivity. Please start a new conversation if you need further assistance."
        }
      )

      # Notify the LA dashboard to remove it from their panel
      ActionCable.server.broadcast(
        "la_queue",
        {
          type: "queue_update",
          action: "remove",
          conversation_id: conversation.id,
          reason: "timeout"
        }
      )

      conversation.close!
    end

    Rails.logger.info "[SessionTimeoutJob] Closed #{timed_out.count} timed-out conversations" if timed_out.any?
  end
end
