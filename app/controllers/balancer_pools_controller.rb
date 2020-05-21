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
  
  def set_uma_address
    @pool = BalancerPool.find(params[:id])
    
    @pool.update_attribute(:uma_address, params[:uma_address])
    
    respond_to do |format|       
      format.js { head :ok }
      format.html { redirect_to root_path }     
    end         
  end

  def set_balancer_address
    @pool = BalancerPool.find(params[:id])
    
    @pool.update_attribute(:bp_address, params[:bp_address])
    
    respond_to do |format|       
      format.js { head :ok }
      format.html { redirect_to root_path }     
    end         
  end

  def set_swaps_completed
    @pool = BalancerPool.find(params[:id])
    
    @pool.update_attribute(:swaps_completed, true)
    
    respond_to do |format|       
      format.js { head :ok }
      format.html { redirect_to root_path }     
    end         
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
    
    # Read the address of the ExpiringMultiPartyCreator (from the uma_prep script)
    @empCreatorAddress = IO.read('db/data/ExpiringMultiPartyCreator.txt')
    @tokenFactoryAddress = IO.read('db/data/TokenFactory.txt')

    @expiry_date_str = UmaExpiryDate.find_by_unix(@pie.uma_expiry_date).date_str
    @uma_collateral = CoinInfo.find_by_coin(@pie.uma_collateral)

    if @pie.price_identifier.nil?
      # need to assign it
      pi = PriceIdentifier.where(:pie_id => nil).first
      if pi.nil?
        raise 'No available price feed identifiers!'
      else
        @pie.update_attribute(:price_identifier, pi.id)
      end
    end

    # Need to convert to Hex for contract
    @price_feed_identifer = Utilities.utf8ToHex(@pie.price_identifier.whitelisted)
    
    @data = YAML::load(@pool.allocation)
    @client_address = @data[:address]
    @abis = Hash.new
    
    # Lots of processing to get the swaps, so do that in the controller
    if @data[:encoding] and @data[:encoding][:transforms]
      @transforms = []
      @data[:encoding][:transforms].each do |t|
        tx = {:method => t[:method], :image => 'AAVE' == t[:method] ? 'aave.svg' : 'uniswap.png'}
        src_coin = CoinInfo.find_by_address(t[:src_coin])
        dest_coin = CoinInfo.find_by_address(t[:dest_coin])
        tx[:src] = src_coin.coin
        tx[:src_addr] = src_coin.address
        # Write as hidden fields in the UI
        @abis[src_coin.coin] = src_coin.abi
        tx[:dest] = dest_coin.coin
        tx[:dest_addr] = dest_coin.address
        tx[:num_tokens] = t[:num_tokens]
        tx[:amount] = t[:amount]
        tx[:amount_to_receive] = t[:amount_to_receive]
        
        @transforms.push(tx)
      end
    else
      @transforms = nil
    end
    
    @pool_config = []
    if @data[:encoding]
      @data[:encoding][:pool].each do |p|
        pc = Hash.new
        info = CoinInfo.find_by_address(p[:coin])
        pc[:coin] = info.coin
        @abis[info.coin] = info.abi
        pc[:coin_addr] = info.address
        pc[:amount] = p[:num_tokens]
        pc[:amount_wei] = p[:amount]
        pc[:weight] = (p[:weight] * 100.0).round(1)
        pc[:denorm] = (p[:weight] * 50).round(2)
        
        @pool_config.push(pc)
      end
    end
    
    if @pool.uma_address.nil?
      @synthetic = nil
    else
      syn_data = YAML::load(@pie.uma_snapshot)
      @synthetic = {:investment => syn_data[:investment], :slices => Hash.new,
                    :net_collateral_adjustment => syn_data[:net_collateral_adjustment]}
      
      @pie.etfs.each do |etf|
        data = syn_data[:slices][etf.ticker]
        current_price = etf.current_price
        performance = (current_price - data[:price])/data[:price] * 100
        
        @synthetic[:slices][etf.ticker] = {:basis => data[:price],
                                           :shares => data[:shares],
                                           :price => current_price,
                                           :performance => performance}
      end

      @pie.stocks.each do |stock|
        data = syn_data[:slices][stock.cca_id]
        current_price = stock.current_price
        performance = (current_price - data[:price])/data[:price] * 100
        
        @synthetic[:slices][stock.company_name] = {:basis => data[:price],
                                                   :shares => data[:shares],
                                                   :price => current_price,
                                                   :performance => performance}
      end
      
      @collateralization, @progress_class, @total_value = @pie.compute_uma_collateralization
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
        
        snap = YAML::load(pie.uma_snapshot)
        collateralization, progress_class = pie.compute_uma_collateralization
        
        current_syn[:current_value] = total_value
        current_syn[:collateralization] = collateralization
        current_syn[:progress_class] = progress_class
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
end
