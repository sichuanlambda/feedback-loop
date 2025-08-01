Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    omniauth_callbacks: 'users/omniauth_callbacks' # Add this line
  }

  root 'architecture_designer#step1'

  # Admin routes
  namespace :admin do
    get 'users/index'
    get 'users/show'
    get 'users/edit'
    get 'users/update'
    get 'users/destroy'
    get 'dashboard', to: 'dashboard#index'
    get 'analytics', to: 'dashboard#analytics'
    resources :building_analyses do
      member do
        patch :toggle_visibility
      end
      collection do
        post :bulk_update
      end
    end
    resources :users do
      member do
        patch :toggle_admin
        get :user_activity
      end
      collection do
        post :bulk_update
      end
    end
    resources :places do
      member do
        post :generate_content
      end
      collection do
        post :auto_generate
        post :generate_all
        get :preview_generation
        post :confirm_generation
        get :merge_duplicates
        post :perform_merge
      end
    end
  end

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
  post 'designs/submit', to: 'designs#submit'
  get 'architecture_explorer/map', to: 'architecture_explorer#map'

  # Route for public user profiles
  get '/users/:handle', to: 'users#show', as: 'user_profile'

  get 'proxy/fetch_street_view', to: 'proxy#fetch_street_view'
  get 'proxy/fetch_satellite_view', to: 'proxy#fetch_satellite_view'

  # Routes for SearchesController
  get '/searches/new', to: 'searches#new'
  post '/searches', to: 'searches#create'

  # Architecture Explorer routes
  get 'architecture_explorer/address_search', to: 'architecture_explorer#address_search'
  get 'architecture_explorer/new', to: 'architecture_explorer#new', as: :architecture_explorer_new
  post 'architecture_explorer', to: 'architecture_explorer#create', as: :architecture_explorer
  get 'architecture_explorer/:id', to: 'architecture_explorer#show', as: :architecture_explorer_show
  post '/process_building_image', to: 'architecture_explorer#process_building_image', as: 'analyze_building'
  patch 'architecture_explorer/:id', to: 'architecture_explorer#update', as: :architecture_explorer_update
  get 'architecture_explorer/:id/status', to: 'architecture_explorer#status', as: :architecture_explorer_status
  get 'style-finder', to: 'architecture_explorer#style_finder', as: :style_finder
  post 'architecture_explorer/analyze_style_preferences', to: 'architecture_explorer#analyze_style_preferences'
  get 'architecture_explorer/:id/building_data', to: 'architecture_explorer#building_data', as: :building_data
  post '/generate_image', to: 'architecture_explorer#generate_image'

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

  namespace :api do
    resources :building_analyses, only: [:index]
  end

  # New Research Prompt Route
  get 'research_prompt', to: 'research_prompt#index', as: 'research_prompt'
  post 'research_prompt', to: 'research_prompt#create'

  get 'development_estimations', to: 'architecture_explorer#development_estimations'
  post 'generate_development_estimation', to: 'architecture_explorer#generate_development_estimation'

  # Places routes
  resources :places, only: [:index, :show], param: :slug
end
