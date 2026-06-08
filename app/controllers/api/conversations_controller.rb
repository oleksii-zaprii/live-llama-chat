class Api::ConversationsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_cors_headers

  # POST /api/conversations
  # Called by the JS widget to start a new conversation session
  def create
    conversation = Conversation.new(
      customer_name:  params[:customer_name].to_s.strip.presence,
      customer_email: params[:customer_email].to_s.strip.presence
    )

    if conversation.save
      render json: {
        session_token:    conversation.session_token,
        conversation_id:  conversation.id,
        status:           conversation.status,
        websocket_url:    "/cable"
      }, status: :created
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/conversations/:token/messages
  # Called by widget on page reload to restore history
  def messages
    conversation = Conversation.find_by!(session_token: params[:token])

    render json: conversation_json(conversation)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found" }, status: :not_found
  end

  # POST /api/conversations/:token/messages
  # Send a customer message (HTTP fallback alongside Action Cable)
  def create_message
    conversation = Conversation.find_by!(session_token: params[:token])
    body = params[:body].to_s.strip

    if body.blank?
      return render json: { error: "Message body is required" }, status: :unprocessable_entity
    end

    if conversation.closed?
      return render json: { error: "Conversation is closed" }, status: :unprocessable_entity
    end

    CustomerMessageProcessor.new(conversation, body).call

    render json: conversation_json(conversation.reload)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found" }, status: :not_found
  end

  def options
    head :ok
  end

  private

  def conversation_json(conversation)
    {
      conversation_id: conversation.id,
      status: conversation.status,
      assigned_agent: conversation.assigned_agent&.name,
      messages: conversation.messages.chronological.map do |m|
        { id: m.id, sender_type: m.sender_type, body: m.body, created_at: m.created_at.iso8601 }
      end
    }
  end

  def set_cors_headers
    response.headers["Access-Control-Allow-Origin"]  = ENV.fetch("WIDGET_ALLOWED_ORIGIN", "*")
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
  end
end
