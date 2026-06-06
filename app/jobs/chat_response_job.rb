class ChatResponseJob < ApplicationJob
  THINKING_MARKER = "...done thinking."

  def perform(chat_id, content)
    chat = Chat.find(chat_id)
    past_thinking = false
    buffer = ""

    chat.ask(content) do |chunk|
      if chunk.content && !chunk.content.empty?
        message = chat.messages.last
        buffer << chunk.content

        if past_thinking
          message.broadcast_append_chunk(chunk.content)
        elsif buffer.include?(THINKING_MARKER)
          past_thinking = true
          after = buffer.split(THINKING_MARKER, 2).last
          message.broadcast_append_chunk(after) if after.present?
        end
      end
    end
  end
end
