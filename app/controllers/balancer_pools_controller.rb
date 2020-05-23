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
    #@pool.update_attributes(:bp_address =>'0xc0b2B0C5376Cb2e6f73b473A7CAA341542F707Ce',
    #                        :uma_address => '0x3b38561ec34300e97551aa1cded230c39c044d99')
                            
    @alloc = YAML::load(@pool.allocation)
    @pie.initialize_uma_snapshot(@alloc[:investment].to_i)
       
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

  def set_bp_address
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

    collateral_coin = CoinInfo.find_by_coin(@pie.uma_collateral)
    base_amount = @data[:investment].to_f * @pie.pct_equities / 100.0
    
    @uma_collateral = {:address => collateral_coin.address,
                       :synthetic_amount => base_amount,
                       :collateral_amount => base_amount * MIN_COLLATERALIZATION}
    
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
        @abis[src_coin.coin] = src_coin.abi unless src_coin.abi.nil?
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
        @abis[info.coin] = info.abi unless info.abi.nil?
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
  
  def calculate_rebalance
    pool = BalancerPool.find(params[:id])
    
    current_allocation = YAML::load(pool.allocation)
    total_value = current_allocation[:investment].to_f
    
    current_tokens = Hash.new
    current_allocation[:encoding][:pool].each do |a|
      current_tokens[a[:coin]] = a[:num_tokens]
    end
    # Say we have a total value of 5000, in three coins
    # Old allocation:
    # 0.3 pBTC 0.058
    # 0.5 aETH 2.33
    # 0.2 DAI  1250
    # New allocation is
    # 0.4 pBTC
    # 0.5 aETH
    # 0.1 DAI
    # Loop through the client array and compare to old allocation.
    # The price could have changed - we are doing percent BY VALUE. So lowering doesn't necessarily mean
    #   you'll get coins back, and vice versa. Need to calculate what the new *value* should be, then
    #   how many coins that is based on the price, and see whether that's more or less than the current 
    #   number of coins.
    # We return to the client an array of coins with changes. If the amount is positive, we are increasing
    #   the number of tokens in the pool, which means they have to come from the wallet - and we need to
    #   approve the spend. Otherwise, if the amount is negative, we will be receiving tokens from the pool.
    # The bind function needs a coin address, amount, and denorm.
    # So we will need to calculate the new denorms, and also the final amount to bind.
    # Return to the client [{'addr':'<coin address>', 'denorm':denorm, 'amount':amount_in_wei, 'approve':boolean}]
    # If approve is true, need to approve the spend
    #
    pending_changes = Hash.new
    result = {:plan => '', :action => Hash.new}
    
    params['coins'].each do |addr, weight|
      new_weight = weight.to_f / 100.0
      coin = CoinInfo.find_by_address(addr)
      
      # Skip the UMA collateral - that is managed in the synthetic console
      #   Can't calculate here because of the collateralization
      next if pool.pie.uma_collateral == coin.coin
            
      # Really this is a general rebalance - we might need to adjust ones that haven't changed percentages, because
      #   of price changes! This is a way to manually rebalance the pool, even if there's low liquidity and nobody is
      #   trading it. As long as you have the coins it needs, of course. Which is why it tells you the plan
      # So we don't care what the old weights were. Just figure out what the token amounts need to be for the new weights,
      #   and if they aren't identical, send down the new amounts.
      old_tokens = current_tokens[addr]
      new_tokens = new_weight * total_value / PriceHistory.latest_price(coin.coin)
      
      if old_tokens != new_tokens
        # There is a change
        diff = new_tokens - old_tokens
        pending_changes[addr] = {:weight => new_weight,
                                 :num_tokens => new_tokens,
                                 :amount => coin.to_wei(new_tokens), 
                                 :denorm => Utilities.to_wei(new_weight / 2.0)}
        action = diff > 0 ? "Deposit" : "Withdraw"
        result[:plan] += "#{action} #{diff.abs.round(2)} #{coin.coin}\n"
        result[:action][addr] = pending_changes[addr]
      end
    end
    
    pool.update_attribute(:pending_changes, YAML::dump(pending_changes))
        
    respond_to do |format|       
      format.js { render :json => result }
      format.html { redirect_to root_path }     
    end         
  end
  
  # The client has updated the Balancer Pool on the blockchain, so we should reflect the changes on the server
  def confirm_rebalance
    pool = BalancerPool.find(params[:id])
    
    unless pool.pending_changes.nil?
      # Pending changes are in the form
      # Hash - address => {weight, num_tokens, amount, denorm}
      # allocation[:encoding][:pool] is an array of the same fields, with :coin => address
      #{"0x5228a22e72ccc52d415ecfd199f99d0665e7733b"=>{:weight=>0.05, :num_tokens=>0.28201521302865161758285889e-1, :amount=>"28201521302865160", :denorm=>"25000000000000000"}, "0xdac17f958d2ee523a2206206994597c13d831ec7"=>{:weight=>0.2, :num_tokens=>1000.0, :amount=>"1000000000", :denorm=>"100000000000000000"}, "0x45804880De22913dAFE09f4980848ECE6EcbAf78"=>{:weight=>0.3, :num_tokens=>0.871586287042417199e0, :amount=>"871586287042417280", :denorm=>"150000000000000000"}} 
      #
      # So loop through the pool array, and if that coin has a change, apply it
      changes = YAML::load(pool.pending_changes)
      
      alloc = YAML::load(pool.allocation)
      edit_pool = alloc[:encoding][:pool]
      edit_pool.each do |slice|
        coin = slice[:coin]
        
        if changes.has_key?(coin)
          slice[:weight] = changes[coin][:weight]
          slice[:num_tokens] = changes[coin][:num_tokens]
          slice[:amount] = changes[coin][:amount]
          slice[:denorm] = changes[coin][:denorm]
        end
      end
      
      pool.update_attributes(:pending_changes => nil, :allocation => YAML::dump(alloc))
    end
    
    respond_to do |format|       
      format.js { head :ok }
      format.html { redirect_to root_path }     
    end         
  end
  
  def set_finalized
    pool = BalancerPool.find(params[:id])

    pool.update_attribute(:finalized, true)
        
    respond_to do |format|       
      format.js { head :ok }
      format.html { redirect_to root_path }     
    end         
  end
  
  def request_withdrawal
    pool = BalancerPool.find(params[:id])
    pie = pool.pie
    amount = params[:amount].to_i
    
    if amount > 0
      snap = YAML::load(pie.uma_snapshot)
  
      # They can't withdraw so much that the collateralization falls below the minimum!     
      snap[:net_collateral_adjustment] -= amount
      @collateralization, @progress_class, @total_value = pie.compute_uma_collateralization(snap[:net_collateral_adjustment])
      
      if @collateralization < MIN_COLLATERALIZATION * 100
        raise 'You cannot withdraw so much that the collateralization falls below the minimum!'
      end
  
      pool.update_attributes(:pending_withdrawal => amount, :withdrawal_available => 2.hours.from_now)    
    end
    
    respond_to do |format|       
      format.js { head :ok }
      format.html { redirect_to root_path }     
    end         
  end
  
private
  def sanity_check
    unless @pool.user == current_user
      redirect_to root_path, :alert => 'Wrong User'
    end
  end  
end
