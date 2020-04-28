Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root :to => 'static_pages#home'
  
  resources :settings, :only => [:show, :update]
  resources :pies, :only => [:show, :edit, :update] do
    member do
      put 'reset'
      get 'edit_allocation'
      put 'update_allocation'
    end
  end
  
  # Don't want to update these in the pie form without submitting
  #resources :cryptos, :only => [:update]
  #resources :stable_coins, :only => [:update]
end
