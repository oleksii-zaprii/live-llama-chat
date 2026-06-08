class CustomerMessageProcessor
  def initialize(conversation, body)
    @conversation = conversation
    @body = body.to_s.strip
  end

  def call
    return false if @body.blank?
    return false unless @conversation && !@conversation.closed?

    if @conversation.ai_managed? && Conversation.triggers_handover?(@body)
      process_keyword_handover
    else
      process_regular_message
    end

    true
  end

  private

  def process_keyword_handover
    msg = @conversation.messages.create!(sender_type: "customer", body: @body)
    broadcast_to_widget(msg)

    @conversation.trigger_handover!

    farewell = @conversation.messages.create!(
      sender_type: "ai",
      body: "I'm connecting you with a Loan Advocate right away. Please hold on — they'll be with you shortly."
    )

    broadcast_to_widget(farewell)
    broadcast_to_la_queue
  end

  def process_regular_message
    msg = @conversation.messages.create!(sender_type: "customer", body: @body)
    broadcast_to_widget(msg)

    case @conversation.status
    when "ai_managed"
      broadcast_ai_thinking
      enqueue_ai_response
    when "agent_managed"
      broadcast_to_la_conversation(msg)
    end
  end

  def broadcast_to_widget(message)
    ActionCable.server.broadcast(
      "conversation_#{@conversation.session_token}",
      {
        type: "message",
        message: message_payload(message),
        conversation_status: @conversation.reload.status
      }
    )
  end

  def broadcast_to_la_conversation(message)
    ActionCable.server.broadcast(
      "la_conversation_#{@conversation.id}",
      { type: "message", message: message_payload(message) }
    )
  end

  def broadcast_ai_thinking
    ActionCable.server.broadcast(
      "conversation_#{@conversation.session_token}",
      {
        type: "ai_thinking",
        model: ENV.fetch("OLLAMA_MODEL", "opploans-chat:latest")
      }
    )
  end

  # Run inline in development so Ollama replies appear reliably (async + SQLite is flaky).
  def enqueue_ai_response
    if Rails.env.development?
      ProcessAiResponseJob.perform_now(@conversation.id)
    else
      ProcessAiResponseJob.perform_later(@conversation.id)
    end
  end

  def broadcast_to_la_queue
    ActionCable.server.broadcast(
      "la_queue",
      {
        type: "queue_update",
        action: "add",
        conversation_id: @conversation.id,
        customer_name: @conversation.customer_name.presence || "Anonymous",
        customer_email: @conversation.customer_email,
        waiting_since: @conversation.updated_at.iso8601
      }
    )
  end

  def message_payload(message)
    {
      id: message.id,
      sender_type: message.sender_type,
      body: message.body,
      created_at: message.created_at.iso8601
    }
  end
end
