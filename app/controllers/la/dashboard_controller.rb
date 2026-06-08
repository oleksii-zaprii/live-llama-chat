class La::DashboardController < ApplicationController
  layout "la"
  before_action :require_la_authentication

  def show
    @queue_conversations = Conversation.awaiting_agent.order(updated_at: :asc)
    @active_conversations = Conversation.agent_managed
                                        .where(assigned_agent_id: current_la_user.id)
                                        .order(updated_at: :desc)
  end
end
