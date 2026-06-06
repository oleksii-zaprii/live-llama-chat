class OllamaClient
  def initialize
    @base_url = ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
    @model    = ENV.fetch("OLLAMA_MODEL", "opploans-chat:latest")
    @conn     = Faraday.new(url: @base_url) do |f|
      f.request  :json
      f.response :json
      f.options.timeout = 120
      f.options.open_timeout = 10
    end
  end

  # conversation: a Conversation record with preloaded messages
  # Returns the response text string, or raises on error
  def chat(conversation)
    messages = build_messages(conversation)
    response = @conn.post("/v1/chat/completions", {
      model: @model,
      messages: messages,
      stream: false,
      temperature: 0.7
    })

    if response.success?
      response.body.dig("choices", 0, "message", "content").to_s.strip
    else
      raise "Ollama API error: #{response.status} — #{response.body}"
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    raise "Ollama connection failed: #{e.message}. Is Ollama running? Try: ollama serve"
  end

  private

  def build_messages(conversation)
    conversation.messages.chronological.map do |msg|
      role = case msg.sender_type
             when "customer" then "user"
             when "ai"       then "assistant"
             when "agent"    then "assistant"
             end
      { role: role, content: msg.body }
    end
  end
end
