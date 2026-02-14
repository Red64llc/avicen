Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resource :profile, only: %i[new create edit update]
  resources :passwords, param: :token

  # Prescriptions CRUD with nested medications (collection actions only)
  resources :prescriptions do
    resources :medications, only: [ :new, :create ]
  end

  # Medications: member actions (shallow) with custom toggle route
  resources :medications, only: [ :edit, :update, :destroy ] do
    member do
      patch :toggle
    end
    # Medication schedules: collection actions nested under medications
    resources :medication_schedules, only: [ :new, :create ]
  end

  # Medication schedules: member actions (shallow)
  resources :medication_schedules, only: [ :edit, :update, :destroy ]

  # Medication logs: create (taken/skipped) and destroy (undo)
  resources :medication_logs, only: [ :create, :destroy ]

  # Daily schedule view
  resource :schedule, only: [ :show ] do
    # Weekly schedule overview
    get :weekly, on: :member
    # Printable medication plan
    get :print, on: :member
  end

  # Adherence history with calendar heatmap
  get "adherence", to: "adherence#index", as: :adherence

  # Drug search for autocomplete
  get "drugs/search", to: "drugs#search", as: :drugs_search
  get "drugs/search_test", to: "drugs#search_test", as: :drugs_search_test if Rails.env.test?

  # Biomarker search for autocomplete
  get "biomarkers/search", to: "biomarker_search#search", as: :biomarkers_search

  # Biomarker index and trend visualization
  get "biomarkers", to: "biomarkers#index", as: :biomarkers
  get "biomarker_trends/:id", to: "biomarker_trends#show", as: :biomarker_trends

  # Biology Reports with nested test results
  resources :biology_reports do
    resources :test_results, only: [ :new, :create, :edit, :update, :destroy ]
  end

  # Document Scanning - AI-powered document capture and extraction
  resources :document_scans, only: [ :new ] do
    collection do
      post :upload       # Handle direct upload completion, shows type selection
      get :select_type   # Display type selection with existing blob (for back navigation)
      post :extract      # Trigger extraction (sync or background)
      post :confirm      # Create final Prescription or BiologyReport record
    end
    member do
      get :review        # Display extracted data in editable form
      delete :cancel     # Cancel extraction and discard data (Requirement 5.7)
    end
  end
  get "document_scans/camera_test", to: "document_scans#camera_test", as: :document_scans_camera_test if Rails.env.test?
  get "document_scans/review_form_test", to: "document_scans#review_form_test", as: :document_scans_review_form_test if Rails.env.test?

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
