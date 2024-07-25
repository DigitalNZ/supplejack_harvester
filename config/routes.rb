require 'sidekiq/web'
require 'sidekiq/cron/web'

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
  
  resources :pipelines, only: %i[index show create update destroy] do
    post :clone, on: :member
    
    resources :pipeline_jobs, only: %i[create show index] do
      post :cancel, on: :member
    end

    resources :schedules

    resources :harvest_definitions, only: %i[create update destroy] do
      resources :extraction_definitions, only: %i[show create update destroy] do
        member do
          post :clone
        end

        resources :extraction_jobs, only: %i[index show create destroy] do
          post :cancel, on: :member
        end

        resources :requests do
          resources :parameters
        end

        resources :stop_conditions, only: %i[create update destroy]
      end

      resources :transformation_definitions, only: %i[create show update destroy] do
        post :test, on: :collection
        post :clone, on: :member

        resources :fields, only: %i[create update destroy] do
          post :run, on: :collection
        end
      end
    end
  end

  resources :destinations do
    post :test, on: :collection
  end

  resources :schemas

  mount Sidekiq::Web => '/sidekiq'

  get '/status', to: proc { [200, { 'Cache-Control' => 'no-store, must-revalidate, private, max-age=0' }, ['ok']] }
end
