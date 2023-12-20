Rails.application.routes.draw do
  devise_for :users
  root 'pages#home'

  # Feedbacks Routes
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

  # Architecture Designer Routes
  resources :architecture_designer, only: [] do
    collection do
      get 'step1'
      get 'step2'
      get 'step3'
      post 'submit', to: 'designs#submit'
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
end
