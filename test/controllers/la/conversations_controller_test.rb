require "test_helper"

class La::ConversationsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    @agent = users(:loan_advocate)
    @conversation = conversations(:awaiting)
    post la_session_path, params: { email: @agent.email, password: "password" }
  end

  test "accept removes conversation from queue broadcast" do
    assert_broadcasts("la_queue", 1) do
      patch accept_la_conversation_path(@conversation)
    end

    assert_redirected_to la_conversation_path(@conversation)
    assert @conversation.reload.agent_managed?
  end
end
