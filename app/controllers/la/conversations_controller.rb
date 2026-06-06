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

      ActionCable.server.broadcast(
        "la_queue",
        { type: "queue_update", action: "remove", conversation_id: @conversation.id, reason: "accepted" }
      )

      join_message = @conversation.messages.create!(
        sender_type: "ai",
        body: "#{current_la_user.name} has joined the chat and is ready to help you."
      )

      ActionCable.server.broadcast(
        "conversation_#{@conversation.session_token}",
        {
          type: "message",
          message: {
            id: join_message.id,
            sender_type: join_message.sender_type,
            body: join_message.body,
            created_at: join_message.created_at.iso8601
          },
          conversation_status: @conversation.status
        }
      )

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
    if body.blank?
      return respond_to do |format|
        format.html { redirect_to la_conversation_path(@conversation), alert: "Message cannot be blank." }
        format.json { render json: { error: "Message cannot be blank." }, status: :unprocessable_entity }
      end
    end

    unless @conversation.assigned_agent_id == current_la_user.id
      return respond_to do |format|
        format.html { redirect_to la_conversation_path(@conversation), alert: "Not authorized." }
        format.json { render json: { error: "Not authorized." }, status: :forbidden }
      end
    end

    msg = @conversation.messages.create!(sender_type: "agent", body: body)
    payload = {
      id: msg.id,
      sender_type: msg.sender_type,
      body: msg.body,
      created_at: msg.created_at.iso8601
    }

    ActionCable.server.broadcast(
      "conversation_#{@conversation.session_token}",
      {
        type: "message",
        message: payload,
        conversation_status: @conversation.status
      }
    )

    ActionCable.server.broadcast(
      "la_conversation_#{@conversation.id}",
      { type: "message", message: payload }
    )

    respond_to do |format|
      format.html { redirect_to la_conversation_path(@conversation) }
      format.json { render json: { message: payload } }
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to la_dashboard_path, alert: "Conversation not found."
  end
end
