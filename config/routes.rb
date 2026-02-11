Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resource :profile, only: %i[new create edit update]
  resources :passwords, param: :token

  # Prescriptions CRUD
  resources :prescriptions

  # Drug search for autocomplete
  get "drugs/search", to: "drugs#search", as: :drugs_search
  get "drugs/search_test", to: "drugs#search_test", as: :drugs_search_test if Rails.env.test?

  # Dashboard for authenticated users
  get "dashboard", to: "dashboard#show", as: :dashboard

  # Landing page for unauthenticated users (explicit route for testing)
  get "landing", to: "pages#home", as: :landing_page

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Dual-root routing: authenticated users see dashboard, unauthenticated users see landing page.
  # The authenticated root must be declared first (Rails matches routes top-down).
  # AuthenticatedConstraint checks if a valid session cookie exists.
  root "dashboard#show", constraints: AuthenticatedConstraint
  root "pages#home", as: :unauthenticated_root
end
