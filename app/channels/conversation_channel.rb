class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = find_conversation
    return reject unless conversation

    stream_from "conversation_#{conversation.session_token}"
    Rails.logger.info "[ConversationChannel] Subscribed to conversation ##{conversation.id}"
  end

  def unsubscribed
    Rails.logger.info "[ConversationChannel] Unsubscribed"
  end

  def receive(data)
    body = data["body"].to_s.strip
    return if body.blank?

    if data["session_token"].present?
      conversation = Conversation.find_by(session_token: data["session_token"])
      CustomerMessageProcessor.new(conversation, body).call if conversation
    elsif data["agent_id"].present?
      handle_agent_message(body, data["agent_id"], data["conversation_id"])
    end
  end

  private

  def find_conversation
    token = params[:session_token] || params[:token]
    return Conversation.find_by(session_token: token) if token

    conversation_id = params[:conversation_id]
    return Conversation.find_by(id: conversation_id) if conversation_id

    nil
  end

  def handle_agent_message(body, agent_id, conversation_id)
    conversation = Conversation.find_by(id: conversation_id, status: "agent_managed")
    return unless conversation
    return unless conversation.assigned_agent_id == agent_id.to_i

    msg = conversation.messages.create!(sender_type: "agent", body: body)

    ActionCable.server.broadcast(
      "conversation_#{conversation.session_token}",
      {
        type: "message",
        message: {
          id: msg.id,
          sender_type: msg.sender_type,
          body: msg.body,
          created_at: msg.created_at.iso8601
        },
        conversation_status: conversation.status
      }
    )

    ActionCable.server.broadcast(
      "la_conversation_#{conversation.id}",
      {
        type: "message",
        message: {
          id: msg.id,
          sender_type: msg.sender_type,
          body: msg.body,
          created_at: msg.created_at.iso8601
        }
      }
    )
  end
end
