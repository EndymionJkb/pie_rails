Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root :to => 'static_pages#works'
  
  resources :settings, :only => [:show, :update] do
    put 'update_coins', :on => :collection
  end
  
  resources :pies, :only => [:show, :edit, :update, :index] do
    member do
      put 'reset'
      get 'edit_allocation'
      put 'update_allocation'
      put 'copy'
      put 'deposit_collateral'
      put 'withdraw_collateral'
      put 'redeem_tokens'
    end
    
    collection do
      get 'synthetics_index'
      get 'balancer_index'
    end
  end

  resources :graphs, :only => [:create, :show]
  resources :balancer_pools, :only => [:show, :edit, :update, :create, :index] do
    member do
      put 'update_balances'
      put 'set_uma_address'
      put 'set_bp_address'
      put 'set_swaps_completed'
      put 'set_finalized'
      put 'calculate_rebalance'
      put 'confirm_rebalance'
      put 'request_withdrawal'
    end
  end
    
  # Don't want to update these in the pie form without submitting
  #resources :cryptos, :only => [:update]
  #resources :stable_coins, :only => [:update]
  
  get '/test', :to => 'static_pages#test'
  get '/about', :to => 'static_pages#about'
  get '/works', :to => 'static_pages#works'
end
