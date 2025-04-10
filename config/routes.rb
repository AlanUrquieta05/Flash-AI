Rails.application.routes.draw do
  # Session routes
  resource :session
  resources :passwords, param: :token
  resources :users, only: [:new, :create]

  # Flash card routes
  resources :flash_card_sets do
    member do
      patch :toggle_favorite
    end
    
    collection do
      post :generate
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root routes - flash_card_sets#index will be the default after authentication
  get 'home' => 'flash_card_sets#index', as: :home
  root 'sessions#new'
end
