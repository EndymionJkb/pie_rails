require 'balance_calculator'

class BalancerPoolsController < ApplicationController
  include ApplicationHelper
  
  respond_to :html, :js
  
  before_action :authenticate_user!
   
  def edit    
    @pool = BalancerPool.find(params[:id])
    sanity_check
    
    # If this is the first time, the investment parameter comes from the pies#show input
    # Otherwise, it's a hidden field on the form. Anyway, update it in the allocation
    @investment = params[:investment]
    @alloc = @pool.allocation.nil? ? Hash.new : YAML::load(@pool.allocation)
    @alloc[:investment] = @investment
    @pool.update_attribute(:allocation, YAML::dump(@alloc))
    
    @avatar = "https://www.gravatar.com/avatar/3643654c087726a2440e9284db1dd5d0"
    @chart_data = @alloc[:chart_data]
    @errors = @alloc[:errors].nil? ? [] : @alloc[:errors]
  end
  
  def update_balances
    @pool = BalancerPool.find(params[:id])
    @alloc = YAML::load(@pool.allocation)
    @error = ''
    
    @address = params[:address]
    
    if @address.blank?
      @error = 'No wallet address found!'
    else
      network = params[:network].to_i
      if 1 == network
        @alloc[:address] = @address
        
        # If we've switched addresses, these are invalid!
        unless @alloc[:address] == @address
          @alloc.delete(:ens_name)
          @alloc.delete(:ens_avatar)
        end
        
        # ENS Lookup address name and avatar
        unless @alloc.has_key?(:ens_name)
          @ens_name = "endymionjkb.eth"
          @alloc[:ens_name] = @ens_name
        end
    
        unless @alloc.has_key?(:ens_avatar)
          @ens_avatar = "https://www.gravatar.com/avatar/3643654c087726a2440e9284db1dd5d0"
          @alloc[:ens_avatar] = @ens_avatar
        end
        
        # Save these results
        @pool.update_attribute(:allocation, YAML::dump(@alloc))
        
        @coins = params[:coins]
        if @coins.nil? or @coins.empty?
          @error = "No coins found!"
        else
          # If we already have a list from earlier, retain that information
          @coins_to_use = @alloc[:coins_to_use]    
          
          # Remove coins that aren't whitelisted
          bad = @coins.keys - BalancerPool.permitted_coins
          bad.each do |c|
            @coins.delete(c)  
          end    
        end
      else
        network_name = get_network_name(network)
        @error = "#{network_name} detected! Please switch to Mainnet."
      end
    end
            
    respond_to do |format|       
      format.js do
        if @error.blank?
          puts @ens_name
          puts @ens_avatar
          render :partial => 'balance_table', :locals => {:coins => @coins, :coins_to_use => @coins_to_use,
                                                          :address => @address, :ens_name => @alloc[:ens_name], 
                                                          :avatar => @alloc[:ens_avatar]}
        else
          render :partial => 'error', :locals => {:error => @error}
        end
      end
      format.html { redirect_to root_path }     
    end         
  end
  
  def update
    @pie = current_user.pie
    @pool = @pie.balancer_pool.nil? ? @pie.create_balancer_pool : @pie.balancer_pool
    
    sanity_check
    
    @investment = params[:investment]
    @coins_to_use = {}
    @chart_data = nil
    
    params.keys.each do |key|
      if key.starts_with?("spend_")
        coin = key[6..key.size]
        @coins_to_use[coin] = params["balance_#{coin}"].gsub(",","").to_i
      end
    end 
    
    @pool.update_attribute(:allocation, YAML::dump({:investment => @investment,
                                                    :coins_to_use => @coins_to_use}))

    @calculator = BalanceCalculator.new(@pie, @coins_to_use, @investment)
    result = @calculator.calculate
    puts result
    if result[:result]
      @chart_data = @calculator.build_chart    
    else
      @errors = result[:errors]
    end
                 
    redirect_to new_balancer_pool_path
  end
  
  def show
  end
  
private
  def sanity_check
    unless @pool.user == current_user
      redirect_to root_path, :alert => 'Wrong User'
    end
  end
end
