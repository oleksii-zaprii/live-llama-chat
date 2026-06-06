require "test_helper"

class CustomerMessageProcessorTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  test "keyword message triggers handover and queue broadcast" do
    conversation = Conversation.create!(customer_name: "Test", status: "ai_managed")

    assert_broadcasts("la_queue", 1) do
      assert_broadcasts("conversation_#{conversation.session_token}", 2) do
        CustomerMessageProcessor.new(conversation, "I need an agent").call
      end
    end

    conversation.reload
    assert conversation.awaiting_agent?
    assert_equal 2, conversation.messages.count
    assert_equal "customer", conversation.messages.first.sender_type
    assert_equal "ai", conversation.messages.last.sender_type
  end

  test "regular message enqueues AI job" do
    conversation = Conversation.create!(customer_name: "Test", status: "ai_managed")

    assert_enqueued_with(job: ProcessAiResponseJob, args: [ conversation.id ]) do
      CustomerMessageProcessor.new(conversation, "What are your hours?").call
    end
  end
end
