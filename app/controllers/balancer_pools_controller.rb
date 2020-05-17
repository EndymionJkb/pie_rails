require 'balance_calculator'

class BalancerPoolsController < ApplicationController
  include ApplicationHelper
  
  respond_to :html, :js
  
  before_action :authenticate_user!, :except => [:index]
  
  def create
    @pool = BalancerPool.find(params[:pool_id])
    sanity_check
    
    @pie = @pool.pie
    # Actually create the pool, based on the calculations
    @pool.update_attributes(:bp_address =>'0xc0b2B0C5376Cb2e6f73b473A7CAA341542F707Ce',
                            :uma_address => '0x3b38561ec34300e97551aa1cded230c39c044d99')
    @alloc = YAML::load(@pool.allocation)
    
    redirect_to @pool
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
    
    @chart_data = @alloc[:chart_data].nil? ? nil : @alloc[:chart_data].to_json.html_safe
    @errors = @alloc[:errors]
    @ens_name = @alloc[:ens_name]
    @ens_avatar = @alloc[:ens_avatar]
    @address = @alloc[:address]
    html = render_to_string :partial => 'balance_table', :locals => {:coins => @alloc[:coins_to_display], 
                                                                     :coins_to_use => @alloc[:coins_to_use], 
                                                                     :investment => @alloc[:investment]}
    @balance_table = html
    @need_btc_address = false
    unless @errors.nil?
      @errors.each do |error|
        if error.has_key?(:coin)
          @need_btc_address = true
          break
        end
      end
    end
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
    # We might need to do more/different swaps, so reset the flag
    @pool.update_attributes(:allocation => YAML::dump(@alloc), :swaps_completed => false)
    
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
    @coins_out = Hash.new
    
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
        
        @coins_in = params[:coins]
        if @coins_in.nil? or @coins_in.empty?
          @error = "No coins found!"
        else
          # If we already have a list from earlier, retain that information
          @coins_to_use = @alloc[:coins_to_use]    
          
          # Remove coins that aren't whitelisted
          bad = @coins_in.keys - Setting.all_currencies
          bad.each do |c|
            @coins_in.delete(c)  
          end   
          
          @coins_in.each do |coin, balance|
            next if 0 == balance.to_f
            # ETH is already converted
            if 'ETH' == coin
              @coins_out[coin] = balance
              next
            end
            
            info = CoinInfo.find_by_coin(coin)
            @coins_out[coin] = info.from_wei(balance)
          end
          
          @alloc[:coins_to_display] = @coins_out 
          @pool.update_attribute(:allocation, YAML::dump(@alloc))
        end
      else
        network_name = get_network_name(network)
        @error = "#{network_name} detected! Please switch to Mainnet."
      end
    end
            
    respond_to do |format|       
      format.js do
        if @error.blank?
          render :partial => 'balance_table', :locals => {:coins => @coins_out, :coins_to_use => @coins_to_use, 
                                                          :investment => @alloc[:investment]}
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
    @steps = ['Review Plan', 'Create Synthetic', 'Swap Tokens', 'Create Balancer', 'Monitor/Adjust']
    @data = YAML::load(@pool.allocation)
    # Lots of processing to get the swaps, so do that in the controller
    if @data.has_key?(:encoding) and @data[:encoding].has_key?(:transforms)
      @transforms = []
      @data[:encoding][:transforms].each do |t|
        tx = {:method => 'AAVE' == t[:method] ? 'aave.svg' : 'uniswap.png'}
        tx[:src] = CoinInfo.find_by_address(t[:src_coin]).coin
        tx[:dest] = CoinInfo.find_by_address(t[:dest_coin]).coin
        tx[:amount] = t[:num_tokens]
        
        @transforms.push(tx)
      end
    else
      @transforms = nil
    end
    
    @pool_config = []
    @data[:encoding][:pool].each do |p|
      pc = Hash.new
      pc[:coin] = CoinInfo.find_by_address(p[:coin]).coin
      pc[:amount] = p[:num_tokens]
      pc[:weight] = (p[:weight] * 100.0).round(1)
      pc[:denorm] = (p[:weight] * 50).round(1)
      
      @pool_config.push(pc)
    end
    
    if @pool.uma_address.nil?
      @synthetic = nil
    else
      syn_data = YAML::load(@pie.uma_snapshot)
      @synthetic = {:investment => syn_data[:investment], :slices => Hash.new}
      @total_value = 0
      
      @pie.etfs.each do |etf|
        data = syn_data[:slices][etf.ticker]
        current_price = etf.current_price
        performance = (current_price - data[:price])/data[:price] * 100
        @total_value += data[:shares] * current_price
        
        @synthetic[:slices][etf.ticker] = {:basis => data[:price],
                                           :shares => data[:shares],
                                           :price => current_price,
                                           :performance => performance}
      end

      @pie.stocks.each do |stock|
        data = syn_data[:slices][stock.cca_id]
        current_price = stock.current_price
        performance = (current_price - data[:price])/data[:price] * 100
        @total_value += data[:shares] * current_price
        
        @synthetic[:slices][stock.company_name] = {:basis => data[:price],
                                                   :shares => data[:shares],
                                                   :price => current_price,
                                                   :performance => performance}
      end
      
      @collateralization = @total_value / syn_data[:investment] * 100
      
      @progress_class = get_progress_class(@collateralization)
    end
  end
  
  def index
    if 'true' == params['uma']
      pools = BalancerPool.where('uma_address IS NOT NULL')
      @synthetics = []
      
      pools.each do |pool|
        pie = pool.pie
        syn_data = YAML::load(pie.uma_snapshot)
        current_syn = {:starting_value => syn_data[:investment]}
        total_value = 0
        
        pie.etfs.each do |etf|
          data = syn_data[:slices][etf.ticker]
          current_price = etf.current_price
          total_value += data[:shares] * current_price
        end
        
        pie.stocks.each do |etf|
          data = syn_data[:slices][stock.cca_id]
          current_price = etf.current_price
          total_value += data[:shares] * current_price
        end
        
        collateralization = total_value / syn_data[:investment] * 100
        
        current_syn[:current_value] = total_value
        current_syn[:collateralization] = collateralization
        current_syn[:progress_class] = get_progress_class(collateralization)
        current_syn[:price_identifier] = pie.price_identifier.whitelisted
        current_syn[:uma_address] = pool.uma_address
        current_syn[:token_symbol] = pie.uma_token_symbol
        current_syn[:token_name] = pie.uma_token_name
        # Is it exipired?
        expiry = UmaExpiryDate.find_by_unix(pie.uma_expiry_date).date_str
        exp_date = Date.strptime(expiry, '%m/%d/%Y')
        diff = (exp_date - Date.today).to_i
        if 0 == diff
          current_syn[:status] = 'Expires today!'
        elsif diff > 0
          current_syn[:status] = "Expires #{expiry} (#{diff} days)"
        else
          current_syn[:status] = "Expired #{expiry} (#{-diff} days ago)"
        end          
        
        @synthetics.push(current_syn)
      end            
      
      render 'synthetics_index'
    else  
      pools = BalancerPool.where('bp_address IS NOT NULL')
      @balancers = []
      
      pools.each do |pool|
        pie = pool.pie
        @balancers.push({:address => pool.bp_address,
                         :url => pool.balancer_url,
                         :gold => pie.pct_gold,
                         :equities => pie.pct_equities,
                         :crypto => pie.pct_crypto,
                         :cash => pie.pct_cash,
                         :synthetic => pie.price_identifier.nil? ? nil : pie.price_identifier.whitelisted})
      end
      
      render 'balancer_index'
    end
  end
  
private
  def sanity_check
    unless @pool.user == current_user
      redirect_to root_path, :alert => 'Wrong User'
    end
  end
  
  def get_progress_class(collateralization)
    if collateralization < Pie::UMA_COLLATERALIZATION * 100
      progress_class = 'bg-danger'
    elsif collateralization > (Pie::UMA_COLLATERALIZATION + 0.2) * 100
      progress_class = 'bg-success'
    else
      progress_class = 'bg-warning'
    end
    
    progress_class    
  end
end
