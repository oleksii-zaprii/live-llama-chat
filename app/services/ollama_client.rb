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
      temperature: 0.0
    })

    if response.success?
      text = extract_content(response.body)
      raise "Ollama returned an empty response" if text.blank?

      text
    else
      raise "Ollama API error: #{response.status} — #{response.body}"
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    raise "Ollama connection failed: #{e.message}. Is Ollama running? Try: ollama serve"
  end

  private

  def extract_content(body)
    message = body.dig("choices", 0, "message") || {}
    message["content"].to_s.strip
  end

  def build_messages(conversation)
    conversation.messages.chronological.filter_map do |msg|
      role = case msg.sender_type
             when "customer" then "user"
             when "ai"       then "assistant"
             when "agent"    then "assistant"
             end
      next if role.nil? || msg.body.blank?

      { role: role, content: msg.body }
    end
  end
end
