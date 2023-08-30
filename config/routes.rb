require 'sidekiq/web'

Sidekiq::Web.app_url = '/'

Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: 'sessions' }, skip: [:registrations]
  as :user do
    get 'edit_profile' => 'devise/registrations#edit', as: :edit_profile
    put 'update_profile' => 'devise/registrations#update', as: :update_profile
    delete 'cancel_account' => 'devise/registrations#destroy', as: :cancel_account
  end

  root 'home#index'

  resources :users, only: %i[index show edit update destroy] do
    collection do
      resource :two_factor_setups, only: %i[show create destroy]
    end
  end

  resources :pipelines, only: %i[index show create update edit destroy] do
    resources :jobs

    resources :harvest_definitions, only: %i[create update] do
      resources :harvest_jobs, only: %i[show create destroy] do
        post :cancel, on: :member
      end

      resources :extraction_definitions, only: %i[show edit new create update] do
        collection do
          post :test
          post :test_record_extraction
          post :test_enrichment_extraction
        end

        resources :extraction_jobs, only: %i[index show create destroy] do
          post :cancel, on: :member
        end

        resources :requests do
          resources :parameters
        end
      end

      resources :transformation_definitions, only: %i[new create show edit update destroy] do
        post :test, on: :collection
        post :update_harvest_definitions, on: :member

        resources :fields, only: %i[create update destroy] do
          post :run, on: :collection
        end
      end
    end
  end

  get :jobs, to: 'extraction_jobs#index', as: :extraction_jobs

  resources :destinations do
    post :test, on: :collection
  end

  mount Sidekiq::Web => '/sidekiq'

  get '/status', to: proc { [200, { 'Cache-Control' => 'no-store, must-revalidate, private, max-age=0' }, ['ok']] }
end
