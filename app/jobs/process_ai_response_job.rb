class ProcessAiResponseJob < ApplicationJob
  queue_as :default

  HANDOVER_TOKEN = "[TRIGGER_HANDOVER]"

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation&.ai_managed?

    response_text = fetch_ai_response(conversation)
    return if response_text.nil?

    if response_text.start_with?(HANDOVER_TOKEN)
      clean_message = response_text.sub(HANDOVER_TOKEN, "").strip
      handle_handover(conversation, clean_message)
    else
      save_and_broadcast_ai_message(conversation, response_text)
    end
  end

  private

  def fetch_ai_response(conversation)
    OllamaClient.new.chat(conversation)
  rescue => e
    Rails.logger.error "[ProcessAiResponseJob] Ollama error for conversation ##{conversation.id}: #{e.message}"
    handle_handover(
      conversation,
      "I'm having trouble connecting right now. Let me connect you with one of our Loan Advocates who can help immediately."
    )
    nil
  end

  def handle_handover(conversation, message_to_customer)
    conversation.trigger_handover!

    msg = conversation.messages.create!(
      sender_type: "ai",
      body: message_to_customer.presence || "I'm connecting you with a Loan Advocate now. Please hold on."
    )

    broadcast_to_widget(conversation, msg)
    broadcast_to_la_queue(conversation)

    Rails.logger.info "[ProcessAiResponseJob] Handover triggered for conversation ##{conversation.id}"
  end

  def save_and_broadcast_ai_message(conversation, text)
    msg = conversation.messages.create!(sender_type: "ai", body: text)
    broadcast_to_widget(conversation, msg)
    Rails.logger.info "[ProcessAiResponseJob] AI reply sent for conversation ##{conversation.id} (#{text.length} chars)"
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
