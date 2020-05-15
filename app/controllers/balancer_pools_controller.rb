require 'balance_calculator'

class BalancerPoolsController < ApplicationController
  include ApplicationHelper
  
  respond_to :html, :js
  
  before_action :authenticate_user!
  
  def create
    @pool = BalancerPool.find(params[:pool_id])
    sanity_check
    
    @pie = @pool.pie
    # Actually create the pool, based on the calculations
    @pool.update_attributes(:bp_address =>'0xc0b2B0C5376Cb2e6f73b473A7CAA341542F707Ce',
                            :uma_address => '0x3b38561ec34300e97551aa1cded230c39c044d99')
    @alloc = YAML::load(@pool.allocation)
    
    render 'show'
  end
   
  def edit    
    @pool = BalancerPool.find(params[:id])
    sanity_check
    
    # If this is the first time, the investment parameter comes from the pies#show input parameters
    # Otherwise, it's already in the allocation, and won't be in the parameters
    @alloc = @pool.allocation.nil? ? Hash.new : YAML::load(@pool.allocation)
    if params.has_key?(:investment)
      @alloc[:investment] = params[:investment]
      @alloc[:chart_data] = nil
      @alloc[:errors] = nil
      @pool.update_attribute(:allocation, YAML::dump(@alloc))              
    end
    
    @investment = @alloc[:investment]    
    @chart_data = @alloc[:chart_data].nil? ? nil : @alloc[:chart_data].to_json.html_safe
    @errors = @alloc[:errors]
  end

  def update
    @pool = BalancerPool.find(params[:id])
    sanity_check

    @alloc = YAML::load(@pool.allocation)
    @coins_to_use = Hash.new
        
    params.keys.each do |key|
      if key.starts_with?("spend_")
        coin = key[6..key.size]
        
        @coins_to_use[coin] = params["balance_#{coin}"].gsub(",","").to_f
      end
    end 
    
    # Update list of coins
    @alloc[:coins_to_use] = @coins_to_use
    @pool.update_attribute(:allocation, YAML::dump(@alloc))
    
    @calculator = BalanceCalculator.new(@pool.pie, @coins_to_use, @alloc[:investment])

    result = @calculator.calculate
    
    if result[:result]
      @alloc[:chart_data] = @calculator.build_chart(result[:disposition])
      @alloc[:encoding] = result[:encoding]
      @alloc[:errors] = nil  
    else
      @alloc[:errors] = result[:errors]
      @alloc[:chart_data] = nil
      @alloc[:encoding] = nil
    end
    @pool.update_attribute(:allocation, YAML::dump(@alloc))
                 
    redirect_to edit_balancer_pool_path(@pool)
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
        
        # Save these results
        @pool.update_attribute(:allocation, YAML::dump(@alloc))
        
        @coins = params[:coins]
        if @coins.nil? or @coins.empty?
          @error = "No coins found!"
        else
          # If we already have a list from earlier, retain that information
          @coins_to_use = @alloc[:coins_to_use]    
          
          # Remove coins that aren't whitelisted
          bad = @coins.keys - Setting.all_currencies
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
          render :partial => 'balance_table', :locals => {:coins => @coins, :coins_to_use => @coins_to_use,
                                                          :address => @address, :ens_name => @alloc[:ens_name], 
                                                          :avatar => @alloc[:ens_avatar], :investment => @alloc[:investment]}
        else
          render :partial => 'error', :locals => {:error => @error}
        end
      end
      format.html { redirect_to root_path }     
    end         
  end
  
  def show
    @pool = BalancerPool.find(params[:id])
    sanity_check
    
    @pie = @pool.pie
  end
  
private
  def sanity_check
    unless @pool.user == current_user
      redirect_to root_path, :alert => 'Wrong User'
    end
  end
end
