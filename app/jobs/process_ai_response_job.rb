class ProcessAiResponseJob < ApplicationJob
  queue_as :default

  HANDOVER_TOKEN = "[TRIGGER_HANDOVER]"

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation&.ai_managed?

    begin
      response_text = OllamaClient.new.chat(conversation)
    rescue => e
      Rails.logger.error "[ProcessAiResponseJob] Ollama error: #{e.message}"
      # Fallback: trigger handover so a human can pick up
      handle_handover(conversation, "I'm having trouble connecting right now. Let me connect you with one of our Loan Advocates who can help immediately.")
      return
    end

    if response_text.start_with?(HANDOVER_TOKEN)
      clean_message = response_text.sub(HANDOVER_TOKEN, "").strip
      handle_handover(conversation, clean_message)
    else
      save_and_broadcast_ai_message(conversation, response_text)
    end
  end

  private

  def handle_handover(conversation, message_to_customer)
    conversation.trigger_handover!

    # Save the AI's parting message to the customer
    msg = conversation.messages.create!(
      sender_type: "ai",
      body: message_to_customer.presence || "I'm connecting you with a Loan Advocate now. Please hold on."
    )

    # Broadcast the AI message down to the customer widget
    broadcast_to_widget(conversation, msg)

    # Broadcast the new conversation card up to the LA dashboard queue
    broadcast_to_la_queue(conversation)

    Rails.logger.info "[ProcessAiResponseJob] Handover triggered for conversation ##{conversation.id}"
  end

  def save_and_broadcast_ai_message(conversation, text)
    msg = conversation.messages.create!(sender_type: "ai", body: text)
    broadcast_to_widget(conversation, msg)
  end

  def broadcast_to_widget(conversation, message)
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

  def broadcast_to_la_queue(conversation)
    # Broadcast a Turbo Stream append to the LA queue panel
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
