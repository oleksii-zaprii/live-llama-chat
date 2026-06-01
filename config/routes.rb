Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Action Cable WebSocket endpoint
  mount ActionCable.server => "/cable"

  # API for the embeddable JS widget (cross-origin)
  namespace :api do
    resources :conversations, only: [ :create ] do
      get :messages, path: "messages/:token", on: :collection
    end
    # Handle CORS preflight OPTIONS requests
    match "conversations", to: "conversations#options", via: :options
    match "conversations/*path", to: "conversations#options", via: :options
  end

  # Convenience: GET /api/conversations/:token/messages
  get "api/conversations/:token/messages", to: "api/conversations#messages", as: :api_conversation_messages

  # Loan Advocate (LA) Portal
  namespace :la do
    resource :session, only: %i[new create destroy]
    resource :dashboard, only: [:show], controller: "dashboard"
    resources :conversations, only: %i[show] do
      member do
        patch :accept
        patch :close
        post  :send_message
      end
    end
  end

  # Root redirects to LA portal login for now
  root "la/sessions#new"
end
