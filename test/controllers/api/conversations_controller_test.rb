require "test_helper"

class Api::ConversationsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "create_message triggers handover for agent keyword" do
    conversation = Conversation.create!(customer_name: "Test", status: "ai_managed")

    assert_broadcasts("la_queue", 1) do
      post api_conversation_create_message_path(conversation.session_token),
           params: { body: "I need an agent" },
           as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "awaiting_agent", json["status"]
    assert json["messages"].any? { |m| m["body"].include?("Loan Advocate") }
  end
end
