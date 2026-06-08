class OllamaHealth
  def self.check
    new.check
  end

  def check
    response = connection.get("/api/tags")

    unless response.success?
      return unavailable("Ollama API returned #{response.status}")
    end

    models = response.body.fetch("models", [])
    installed = models.any? { |m| model_names(m["name"]).include?(configured_model) }

    {
      available: true,
      base_url: base_url,
      model: configured_model,
      model_installed: installed,
      installed_models: models.map { |m| m["name"] }
    }
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError
    unavailable("Cannot reach Ollama at #{base_url}. Is `ollama serve` running?")
  rescue => e
    unavailable(e.message)
  end

  private

  def unavailable(error)
    {
      available: false,
      base_url: base_url,
      model: configured_model,
      model_installed: false,
      error: error
    }
  end

  def model_names(name)
    base = name.to_s.sub(/:latest\z/, "")
    [ name.to_s, base, "#{base}:latest" ].uniq
  end

  def configured_model
    ENV.fetch("OLLAMA_MODEL", "opploans-chat:latest")
  end

  def base_url
    ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
  end

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 5
      f.options.open_timeout = 2
    end
  end
end
