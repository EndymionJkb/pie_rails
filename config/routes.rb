Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root :to => 'pies#show'
  
  resources :settings, :only => [:show, :update]
  resources :pies, :only => [:show, :edit, :update, :index] do
    member do
      put 'reset'
      get 'edit_allocation'
      put 'update_allocation'
      put 'copy'
    end
  end

  resources :graphs, :only => [:create, :show]
  resources :balancer_pools, :only => [:new, :create, :show]
    
  # Don't want to update these in the pie form without submitting
  #resources :cryptos, :only => [:update]
  #resources :stable_coins, :only => [:update]
  
  get '/test', :to => 'static_pages#test'
end
