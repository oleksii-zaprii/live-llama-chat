class Dev::ChatSimulatorController < ApplicationController
  layout false

  def show
    @ollama = OllamaHealth.check
  end
end
