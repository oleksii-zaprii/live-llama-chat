require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "trigger_handover! moves conversation to awaiting_agent" do
    conversation = Conversation.create!(customer_name: "Test User")

    conversation.trigger_handover!

    assert conversation.awaiting_agent?
    assert_nil conversation.assigned_agent_id
  end

  test "accept_by! assigns agent and moves to agent_managed" do
    agent = users(:loan_advocate)
    conversation = Conversation.create!(customer_name: "Test User", status: "awaiting_agent")

    conversation.accept_by!(agent)

    assert conversation.agent_managed?
    assert_equal agent.id, conversation.assigned_agent_id
  end

  test "triggers_handover? detects keywords" do
    assert Conversation.triggers_handover?("I need to speak to an agent")
    refute Conversation.triggers_handover?("What are your hours?")
  end
end
