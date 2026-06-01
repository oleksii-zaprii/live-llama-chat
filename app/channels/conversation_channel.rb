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

    # Identify source: widget sends session_token, LA sends agent_id
    if data["session_token"].present?
      handle_customer_message(body, data["session_token"])
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

  def handle_customer_message(body, session_token)
    conversation = Conversation.find_by(session_token: session_token)
    return unless conversation && !conversation.closed?

    # Deterministic keyword check — overrides AI
    if conversation.ai_managed? && Conversation.triggers_handover?(body)
      Rails.logger.info "[ConversationChannel] Keyword handover triggered for conversation ##{conversation.id}"
      msg = conversation.messages.create!(sender_type: "customer", body: body)
      broadcast_message_to_widget(conversation, msg)
      trigger_handover_broadcast(conversation)
      return
    end

    msg = conversation.messages.create!(sender_type: "customer", body: body)
    broadcast_message_to_widget(conversation, msg)

    case conversation.status
    when "ai_managed"
      ProcessAiResponseJob.perform_later(conversation.id)
    when "agent_managed"
      # Forward directly to the LA portal channel
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

  def handle_agent_message(body, agent_id, conversation_id)
    conversation = Conversation.find_by(id: conversation_id, status: "agent_managed")
    return unless conversation
    return unless conversation.assigned_agent_id == agent_id.to_i

    msg = conversation.messages.create!(sender_type: "agent", body: body)

    # Send to customer widget
    broadcast_message_to_widget(conversation, msg)

    # Echo back to LA panel (for multi-tab support)
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

  def broadcast_message_to_widget(conversation, message)
    ActionCable.server.broadcast(
      "conversation_#{conversation.session_token}",
      {
        type: "message",
        message: {
          id: message.id,
          sender_type: message.sender_type,
          body: message.body,
          created_at: message.created_at.iso8601
        },
        conversation_status: conversation.status
      }
    )
  end

  def trigger_handover_broadcast(conversation)
    conversation.trigger_handover!

    farewell = conversation.messages.create!(
      sender_type: "ai",
      body: "I'm connecting you with a Loan Advocate right away. Please hold on — they'll be with you shortly."
    )

    broadcast_message_to_widget(conversation, farewell)

    ActionCable.server.broadcast(
      "la_queue",
      {
        type: "queue_update",
        action: "add",
        conversation_id: conversation.id,
        customer_name: conversation.customer_name.presence || "Anonymous",
        customer_email: conversation.customer_email,
        waiting_since: conversation.updated_at.iso8601
      }
    )
  end
end
