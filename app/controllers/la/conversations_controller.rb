class La::ConversationsController < ApplicationController
  layout "la"
  before_action :require_la_authentication
  before_action :set_conversation

  def show
    @messages = @conversation.messages.chronological
  end

  # PATCH /la/conversations/:id/accept
  def accept
    if @conversation.awaiting_agent?
      @conversation.accept_by!(current_la_user)
      redirect_to la_conversation_path(@conversation), notice: "Chat accepted. You're now connected with the customer."
    else
      redirect_to la_dashboard_path, alert: "This conversation is no longer available."
    end
  end

  # PATCH /la/conversations/:id/close
  def close
    @conversation.close!

    # Notify the customer widget
    ActionCable.server.broadcast(
      "conversation_#{@conversation.session_token}",
      {
        type: "session_closed",
        message: "This chat has been closed by our team. Thank you for contacting OppLoans!"
      }
    )

    # Remove from LA queue / panels
    ActionCable.server.broadcast(
      "la_queue",
      { type: "queue_update", action: "remove", conversation_id: @conversation.id, reason: "closed_by_agent" }
    )

    redirect_to la_dashboard_path, notice: "Conversation closed."
  end

  # POST /la/conversations/:id/messages
  def send_message
    body = params[:body].to_s.strip
    return redirect_to la_conversation_path(@conversation), alert: "Message cannot be blank." if body.blank?
    return redirect_to la_conversation_path(@conversation), alert: "Not authorized." unless @conversation.assigned_agent_id == current_la_user.id

    msg = @conversation.messages.create!(sender_type: "agent", body: body)

    # Push to customer widget
    ActionCable.server.broadcast(
      "conversation_#{@conversation.session_token}",
      {
        type: "message",
        message: { id: msg.id, sender_type: msg.sender_type, body: msg.body, created_at: msg.created_at.iso8601 },
        conversation_status: @conversation.status
      }
    )

    # Echo to LA panel (Turbo Stream)
    ActionCable.server.broadcast(
      "la_conversation_#{@conversation.id}",
      {
        type: "message",
        message: { id: msg.id, sender_type: msg.sender_type, body: msg.body, created_at: msg.created_at.iso8601 }
      }
    )

    redirect_to la_conversation_path(@conversation)
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to la_dashboard_path, alert: "Conversation not found."
  end
end
