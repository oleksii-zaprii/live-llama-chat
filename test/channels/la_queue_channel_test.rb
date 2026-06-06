require "test_helper"

class LaQueueChannelTest < ActionCable::Channel::TestCase
  tests LaQueueChannel

  test "subscribes when loan advocate is authenticated" do
    stub_connection(current_la_user: users(:loan_advocate))

    subscribe

    assert subscription.confirmed?
    assert_has_stream "la_queue"
  end

  test "rejects unauthenticated connections" do
    stub_connection(current_la_user: nil)

    subscribe

    assert subscription.rejected?
  end
end
