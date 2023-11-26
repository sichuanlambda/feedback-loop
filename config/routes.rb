Rails.application.routes.draw do
  # Define the root (home page) route
  root 'feedbacks#roastery'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  get "feedbacks/new", to: "feedbacks#new"
  get "about", to: "feedbacks#about"
  post "feedbacks", to: "feedbacks#create"
  post 'ask_gpt', to: 'feedbacks#ask_gpt', defaults: { format: :json }
  get "thank_you", to: "feedbacks#thank_you"
  get 'feedbacks/dashboard', to: 'feedbacks#dashboard', as: 'feedbacks_dashboard'
  get 'screenshot_searcher', to: 'feedbacks#screenshot_searcher'
  post 'analyze_screenshot', to: 'feedbacks#analyze_screenshot', as: 'analyze_screenshot'

  # Route for the Roastery page
  get "roastery", to: "feedbacks#roastery"

  # this is for displaying the feedback on the dashboard(?)
  resources :feedbacks do
    get 'dashboard', on: :collection  # This will route to feedbacks#dashboard
    member do
      patch 'submit_comment'
    end
  end

  # these are for two buttons
  get 'thumbs_up', to: 'feedbacks#thumbs_up'
  get 'thumbs_down', to: 'feedbacks#thumbs_down'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
