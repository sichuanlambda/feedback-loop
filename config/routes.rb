Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    omniauth_callbacks: 'users/omniauth_callbacks' # Add this line
  }

  root 'architecture_designer#step1'

  # Feedbacks Routes
  get '/auth/:provider/callback', to: 'sessions#create_from_omniauth'
  get '/auth/failure', to: 'sessions#omniauth_failure'
  get "feedbacks/new", to: "feedbacks#new"
  get "about", to: "feedbacks#about"
  post "feedbacks", to: "feedbacks#create"
  get "thank_you", to: "feedbacks#thank_you"
  get 'feedbacks/dashboard', to: 'feedbacks#dashboard', as: 'feedbacks_dashboard'
  post 'ask_gpt', to: 'feedbacks#ask_gpt', defaults: { format: :json }
  get 'screenshot_searcher', to: 'feedbacks#screenshot_searcher'
  post 'analyze_screenshot', to: 'feedbacks#analyze_screenshot', as: 'analyze_screenshot'
  get 'custom_sign_out', to: 'feedbacks#custom_sign_out'
  get 'sign_out_confirmation', to: 'feedbacks#sign_out_confirmation'
  get 'designs/show_image', to: 'designs#show_image', as: 'show_image'
  get 'user_creations', to: 'designs#user_creations'
  get 'building_library', to: 'architecture_explorer#building_library'
  post 'add_to_library/:id', to: 'architecture_explorer#add_to_library', as: 'add_to_library'
  post 'remove_from_library/:id', to: 'architecture_explorer#remove_from_library', as: 'remove_from_library'
  get '/account', to: 'pages#account'
  get '/home', to: 'pages#home'
  get 'building_library/styles/:style_name', to: 'architecture_explorer#by_style', as: 'buildings_by_style'
  get 'building_library/locations/:location_name', to: 'architecture_explorer#by_location', as: 'buildings_by_location'
  get '/auth/:provider/callback', to: 'sessions#create_from_omniauth'
  get '/auth/failure', to: 'sessions#omniauth_failure'
  post '/stripe_events', to: 'stripe_events#create'

  # Route for public user profiles
  get '/users/:handle', to: 'users#show', as: 'user_profile'

  get 'proxy/fetch_street_view', to: 'proxy#fetch_street_view'

  # Architecture Explorer routes
  get 'architecture_explorer/address_search', to: 'architecture_explorer#address_search'
  get 'architecture_explorer/new', to: 'architecture_explorer#new', as: :architecture_explorer_new
  post 'architecture_explorer', to: 'architecture_explorer#create', as: :architecture_explorer
  get 'architecture_explorer/:id', to: 'architecture_explorer#show', as: :architecture_explorer_show
  post '/process_building_image', to: 'architecture_explorer#process_building_image', as: 'analyze_building'
  patch 'architecture_explorer/:id', to: 'architecture_explorer#update', as: :architecture_explorer_update

  # Architecture Designer Routes
  resources :architecture_designer, only: [] do
    collection do
      get 'step1'
      get 'step2'
      get 'step3'
      post 'submit', to: 'designs#submit'

      # Nested User Creations route
      get 'user_creations', to: 'designs#index'
    end
  end

  # Dog Rating Page Routes
  get '/rate_my_dog', to: 'feedbacks#rate_my_dog'
  post '/process_dog_image', to: 'feedbacks#process_dog_image', as: 'rate_dog'
  post '/upload_to_s3', to: 'feedbacks#upload_to_s3'

  # Roastery Page Route
  get "roastery", to: "feedbacks#roastery"

  # Feedbacks Resource
  resources :feedbacks do
    get 'dashboard', on: :collection
    member do
      patch 'submit_comment'
    end
  end

  # Miscellaneous Routes
  get 'thumbs_up', to: 'feedbacks#thumbs_up'
  get 'thumbs_down', to: 'feedbacks#thumbs_down'
  get "up" => "rails/health#show", as: :rails_health_check

  # Stripe Checkout Route
  post '/stripe_checkout', to: 'stripe#checkout'
  post '/create_stripe_checkout_session', to: 'stripe#create_checkout_session'
end
