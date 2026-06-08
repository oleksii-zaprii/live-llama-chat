class LaConversationChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_la_user

    conversation = Conversation.find_by(id: params[:conversation_id])
    return reject unless conversation

    authorized =
      conversation.awaiting_agent? ||
      (conversation.agent_managed? && conversation.assigned_agent_id == current_la_user.id)

    return reject unless authorized

    stream_from "la_conversation_#{conversation.id}"
    Rails.logger.info "[LaConversationChannel] User ##{current_la_user.id} subscribed to conversation ##{conversation.id}"
  end

  def unsubscribed
    Rails.logger.info "[LaConversationChannel] User unsubscribed"
  end
end
