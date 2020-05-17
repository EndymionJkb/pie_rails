class BalanceCalculator
  @graph = nil
  @pie = nil
  @pool = nil
  @starting_coins = nil
  @investment = nil
  @setting = nil
  
  COIN_LIST_EMPTY = 'Start coin list empty'
  INVALID_INVESTMENT = 'Invalid initial investment'
  INVALID_PIE = 'Invalid Pie'
  INSUFFICIENT_FUNDS = 'Insufficient Funds'
  # Need at least this much, for gas costs
  ETH_RESERVE = 0.5
  
  def initialize(pie, starting_coins, investment)
    @investment = investment.to_i

    raise 'Invalid investment' if @investment <= 0
    
    @pie = pie
    @starting_coins = starting_coins
    # Plan for conversion
    @disposition = Hash.new
    @errors = []
    @ptoken_errors = []
    @setting = @pie.setting
  end
  
  # Algorithm - try to keep it simple; optimizing would be really hard!
  # Principle: do not sell crypto for cash! Only cash for crypto
  #
  # Possible dispositions:
  #   1) Directly use the currency
  #   2) Uniswap a stable coin for the currency
  #   3) Get an aToken from AAVE (from the regular version)
  #   4) Uniswap a stable coin for a token - THEN get an aToken from AAVE
  # 
  # Possible errors (assuming valid inputs)
  #   1) Insufficient funds
  #   2) Missing pTokens
  #   3) Coins not available to swap
  #   4) Out of gas/resources
  #
  def calculate
    # Validate inputs
    if @starting_coins.keys.empty?
      {:result => false, 
       :errors => [{:msg => COIN_LIST_EMPTY}]}
    elsif @investment.to_i <= 0
      {:result => false, 
       :errors => [{:msg => INVALID_INVESTMENT}]}   
    elsif @pie.nil? or !@pie.valid?
      {:result => false, 
       :errors => [{:msg => INVALID_PIE}]}            
    end
    
    # Types of input coins:
    # 1) Stable coins
    # 2) Crypto
    # 3) AAVE
    # 4) pTokens
    stable_in = Hash.new
    crypto_in = Hash.new
    aave_in = Hash.new
    ptokens_in = Hash.new
    
    @errors = []
    @ptoken_errors = []
    
    @starting_coins.each do |coin, balance|
      if Setting::STABLE_COINS.include?(coin)
        stable_in[coin] = balance
      elsif 'a' == coin[0]
        aave_in[coin] = balance
      elsif 'p' == coin[0]
        ptokens_in[coin] = balance
      else
        crypto_in[coin] = balance
      end
    end
    
    # Disposition creates human-readable text for the chart
    # We also need the smart contract encoding
    # This will be returned in the :encoding key returned from this function
    # There are three components the smart contract needs
    # :encoding => {:synthetic => synthetic_data, :transforms => transformations, :pool => pool_data}
    # The synthetic data are processed by the SyntheticBuilder contract (creates an UMA synthetic)
    # The transform data are processed by the TransformationEngine contract (token swaps)
    # The pool data are processed by the PoolManager contract (constructs the Balancer pool, when all tokens are present)
                     
    # Adjust for ETH reserve
    if crypto_in['ETH'].to_f < ETH_RESERVE
      return {:result => false, :errors => [{:msg => "Missing ETH reserves (at least #{ETH_RESERVE} required)"}]}
    else
      crypto_in['ETH'] -= ETH_RESERVE
    end
    
    # Now what does the Pie need?
    # The pie doesn't know prices or the amount,
    #   so these numbers are percentages (0-1; already normalized to decimal)
    # Since PAXG is on Uniswap, I can treat it like just another Crypto
    stable_out = @pie.stable_coin_needs
    crypto_out = @pie.crypto_needs
    ptokens_out = @pie.ptoken_needs
    aave_out = @pie.aave_needs

    @disposition, @errors, @ptoken_errors, @encoding = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                                          stable_out, crypto_out, ptokens_out, aave_out)    
    
    if @errors.empty? and @ptoken_errors.empty?
      # The synthetic data is independent of the processing here, so we can fill it right in from the pie
      @encoding[:synthetic] = {:token_symbol => @pie.uma_token_symbol, 
                               :token_name => @pie.uma_token_name,
                               :collateral => CoinInfo.find_by_coin(@pie.uma_collateral).address,
                               :expiry_date => @pie.uma_expiry_date,
                               :next_month => @pie.uma_next_month}
        
      result = {:result => true,
                :disposition => @disposition,
                :encoding => @encoding}
    else 
      result = {:result => false, :errors => []}
      @errors.each do |err|
        result[:errors].push({:msg => err})
      end
      @ptoken_errors.each do |err|
        result[:errors].push(err)
      end
    end
    
    result
  end
  
  # Mainly do this to facilitate testing - this takes hashes in, and produces hashes out
  def calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                         stable_out, crypto_out, ptokens_out, aave_out)
    @disposition = Hash.new
    @errors = []
    @ptoken_errors = []
    @encoding = {:transforms => [], :pool => []}
    
    # Cannot do anything if pTokens are missing - so check that first
    # And keep going, since there could be other errors, and this is independent
    ptokens_out.each do |coin_out, pct|
      price = PriceHistory.latest_price(coin_out)
      
      amount_needed = pct * @investment / price
    
      if ptokens_in[coin_out].to_f >= amount_needed
        @disposition[coin_out] = ["Take #{amount_needed.round(2)} #{coin_out} from balance"]
        coin_data = CoinInfo.find_by_coin('pBTC')
        
        @encoding[:pool].push({:coin => coin_data.address,
                               :num_tokens => amount_needed,
                               :amount => coin_data.to_wei(amount_needed),
                               :weight => pct,
                               :denorm => Utilities.to_wei(pct*50) })
      else
        @ptoken_errors.push({:coin => coin_out, :amount => amount_needed, :address => '14a4aHGFggMCne6AuVszrtiDfSZbcCr51L'})
      end
    end
    
    # Edit the balances in the _in hashes; if 0 delete
    # As each _out hash is satisfied, remove it, and populate @disposition
    
    # Uniswap has all stable coins except USDT - so if we need USDT out, must have USDT in
    # Special case!
    if stable_out.keys.include?('USDT')
      amount_needed = stable_out['USDT'] * @investment
      # Do we have enough?
      if stable_in['USDT'].to_f >= amount_needed
        # take it
        stable_in['USDT'] -= amount_needed
        @disposition['USDT'] = ["Take #{amount_needed} from USDT balance"]
        coin_data = CoinInfo.find_by_coin('USDT')
        @encoding[:pool].push({:coin => coin_data.address,
                               :num_tokens => amount_needed,
                               :amount => coin_data.to_wei(amount_needed), 
                               :weight => stable_out['USDT'],
                               :denorm => Utilities.to_wei(stable_out['USDT'] * 50.0)})
        if 0 == stable_in['USDT']
          stable_in.delete('USDT')
        end
      else        # Could get here if stable_in has no USDT key - nil.to_f = 0
        shortfall = (amount_needed - stable_in['USDT'].to_f).ceil
        @errors.push("Short #{shortfall.round(2)} USDT for Cash allocation")        
      end
      
      # Remove it from stable_out so that it doesn't trigger *again* when calculating general stable coins
      stable_out.delete('USDT')
    end

    # Now try to match stable coin needs directly
    # If we are short, *might* be able to make up for it with other coins
    # Keep track of any "short" amounts
    # Don't try to figure it out in the middle - do all the direct transfers we can first
    shortfall_amounts = calculate_shortfalls(stable_out, stable_in)
            
    if shortfall_amounts.empty? or address_shortfalls(shortfall_amounts, stable_in, 'Cash')
      # Now try to get AAVE coins, if they're not already there
      # If we already have the AAVE coin, use it
      # If we have it but not enough, or don't have it, check if we have the corresponding asset
      #   and use that. Otherwise, figure out the price and try to use ETH
      aave_out.each do |coin, pct|
        base_coin = coin[1,coin.size]
        # To calculate amount needed (of the base coin; i.e, WBTC if it's aWBTC), we need the price
        # It could be a stable coin, in which case the base price is 1; otherwise get the price
        if Setting::STABLE_COINS.include?(base_coin)
          price = 1
        else
          price = PriceHistory.latest_price(base_coin)
        end
        
        amount_needed = pct * @investment / price
        try_eth = false
        coin_data = CoinInfo.find_by_coin(coin)
        @encoding[:pool].push({:coin => coin_data.address,
                               :num_tokens => amount_needed,
                               :amount => coin_data.to_wei(amount_needed),
                               :weight => pct,
                               :denorm => Utilities.to_wei(pct*50.0) })
        
        # Do we have enough atokens?
        if aave_in[coin].to_f >= amount_needed
          # Yes! take it
          @disposition[coin] = [] unless @disposition.has_key?(coin)
          @disposition[coin].push("Take #{amount_needed.round(2)} from #{coin} balance")
        else
          
          # If we have some...
          if aave_in[coin].to_f > 0
            amount_needed -= aave_in[coin]
            @disposition[coin] = [] unless @disposition.has_key?(coin)
            @disposition[coin].push("Take #{aave_in[coin]} from #{coin} balance")
          end
          
          # Now see if we have enough base coin (base could be a stable coin or a crypto)
          if Setting::STABLE_COINS.include?(base_coin)
            # It's a stable coin
            if stable_in[base_coin].to_f >= amount_needed
              # Yes, we have enough!
              @disposition[coin] = [] unless @disposition.has_key?(coin)
              @disposition[coin].push("Deposit #{amount_needed.round(2)} #{base_coin} to AAVE for #{coin}")
              stable_in[base_coin] -= amount_needed
              src_coin = CoinInfo.find_by_coin(base_coin)
              dest_coin = CoinInfo.find_by_coin(coin)
              # AAVE coins are pegged 1-to-1, so use amount_needed for both
              @encoding[:transforms].push({:method => 'AAVE', 
                                           :src_coin => src_coin.address,
                                           :dest_coin => dest_coin.address,
                                           :num_tokens => amount_needed.round(2),
                                           :amount => src_coin.to_wei(amount_needed) })
            else
              try_eth = true
            end
          else
            # It's a crypto
            if crypto_in[base_coin].to_f >= amount_needed
              # Yes, we have enough!
              @disposition[coin] = [] unless @disposition.has_key?(coin)
              @disposition[coin].push("Deposit #{amount_needed.round(2)} #{base_coin} to AAVE for #{coin}")
              crypto_in[base_coin] -= amount_needed
              src_coin = CoinInfo.find_by_coin(base_coin)
              dest_coin = CoinInfo.find_by_coin(coin)
              # AAVE coins are pegged 1-to-1, so use amount_needed for both
              @encoding[:transforms].push({:method => 'AAVE', 
                                           :src_coin => src_coin.address,
                                           :dest_coin => dest_coin.address,
                                           :num_tokens => amount_needed.round(2),
                                           :amount => src_coin.to_wei(amount_needed) })
            else
              try_eth = true
            end
          end
          
          # At this point, we don't have enough aTokens from input, and can't exchange enough base tokens for them
          # So have to try to exchange ETH for them
          # Which means we need to recalculate the amount needed in terms of ETH
          # We might have already subtracted some (if we had aTokens),
          #   so the calculation is: amount_needed = amount_needed (Base) * Price(Base)/Price(ETH)
          # If it's aWBTC, and WBTC is 10k while ETH is 1k, and amount_needed was 0.2 WBTC, the new amount is 0.2 * 10000/1000 = 2 ETH
          if try_eth
            price_eth = PriceHistory.latest_price('ETH')
            original_amount = amount_needed
            amount_needed *= price / price_eth
            
            # Do we have enough ETH?
            if crypto_in['ETH'].to_f >= amount_needed
              # Yes!
              @disposition[coin] = [] unless @disposition.has_key?(coin)
              @disposition[coin].push("Deposit #{amount_needed.round(2)} ETH to AAVE for #{coin}")
              src_coin = CoinInfo.find_by_coin('ETH')
              dest_coin = CoinInfo.find_by_coin(coin)
              # AAVE coins are pegged 1-to-1, so use amount_needed for both
              @encoding[:transforms].push({:method => 'AAVE', 
                                           :src_coin => src_coin.address,
                                           :dest_coin => dest_coin.address,
                                           :num_tokens => amount_needed.round(2),
                                           :amount => src_coin.to_wei(amount_needed) })
              crypto_in['ETH'] -= amount_needed
            else
              @errors.push("Short #{amount_needed.round(2)} ETH to swap for #{original_amount.round(2)} of #{coin} in AAVE allocation (or collateral)")
            end
          end
        end
      end
      
      # Now try to find all the crypto tokens
      # Either we have them, or can buy them with stable coins
      shortfall_amounts = calculate_shortfalls(crypto_out, crypto_in)
      
      address_shortfalls(shortfall_amounts, stable_in, 'Crypto') unless shortfall_amounts.empty?
    end    
    
    return @disposition, @errors, @ptoken_errors, @encoding
  end

  def build_chart(disposition)
    data = Hash.new
    data[:chart] = {:type => 'pie'}
    data[:title] = {:text => "#{@pie.name} Plan"}
    data[:subtitle] = {:text => 'Click slices to view plans for constituents'}
    data[:plotOptions] = {:series => {:dataLabels => {:enabled => true, :format => '{point.name}<br>{point.y:.1f}%'}}}
    data[:tooltip] = {:headerFormat => '<span style="font-size:11px">{series.name}</span><br>',
                      :pointFormat => '<span style="color:{point.color}">{point.desc}</span>: <b>{point.y:.2f}%</b> of total<br/>'}
    data[:series] = [build_primary_series]
    data[:drilldown] = {:series => build_drilldown_series(disposition)}
    
    data
  end
  
  def test_engine
    passed = 0
    failed = 0
    
    # Latest prices - in case db changes
    # pBTC = 8864.77 
    
    # Test every pToken (success)
    # pTokens are either there or not. If there, use the balance
    # If not there, go to ptokens protocol, get the address, and show the amount
    Setting.all_currencies.each do |curr|
      next unless 'p' == curr[0]
      
      stable_in = crypto_in = aave_in = Hash.new
      stable_out = crypto_out = aave_out = Hash.new
      
      # In is a pct of 10000
      ptokens_in = {curr => 1}
      ptokens_out = {curr => 0.5}
      
      @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                                 stable_out, crypto_out, ptokens_out, aave_out)
      if 1 == @disposition.count  and @errors.empty? and @ptoken_errors.empty?
        passed += 1
      else 
        failed += 1
        puts @disposition
        puts @ptoken_errors
        raise '1'
      end                                                   
    end

    # Test every pToken (none at all)
    Setting.all_currencies.each do |curr|
      next unless 'p' == curr[0]
      
      stable_in = crypto_in = aave_in = ptokens_in = Hash.new
      stable_out = crypto_out = aave_out = Hash.new
      
      # In is a pct of 10000
      ptokens_out = {curr => 0.5}
      
      @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                                 stable_out, crypto_out, ptokens_out, aave_out)
      if @disposition.empty?  and @errors.empty? and 1 == @ptoken_errors.count
        puts @ptoken_errors
        passed += 1
      else 
        failed += 1
        puts @disposition
        puts @errors
        raise '2'
      end                                                   
    end

    # Test every pToken (not enough)
    Setting.all_currencies.each do |curr|
      next unless 'p' == curr[0]
      
      stable_in = crypto_in = aave_in = Hash.new
      stable_out = crypto_out = aave_out = Hash.new
      
      # In is a pct of 10000
      ptokens_in = {curr => 0.1}
      ptokens_out = {curr => 0.5}
      
      @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                                 stable_out, crypto_out, ptokens_out, aave_out)
      if @disposition.empty?  and @errors.empty? and 1 == @ptoken_errors.count
        puts @ptoken_errors
        passed += 1
      else 
        failed += 1
        puts @disposition
        puts @errors
        raise '3'
      end                                                   
    end
    
    # Test Tether. USDT cannot be swapped by Uniswap. So it's like a pToken, we either have it or we don't.
    crypto_in = aave_in = ptokens_in = Hash.new
    crypto_out = aave_out = ptokens_out = Hash.new
    
    # With investment of 10,000, have 2000; need 5000
    stable_in = {'USDT' => 2000}
    stable_out = {'USDT' => 0.5}
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    if @disposition.empty? and 1 == @errors.count and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @errors
      raise '4'
    end

    # With investment of 10,000, have 7000; need 5000
    stable_in = {'USDT' => 7000}
    stable_out = {'USDT' => 0.5}
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    if 1 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @errors
      raise '5'
    end
    
    # Now test other stable coins - 
    crypto_in = aave_in = ptokens_in = Hash.new
    crypto_out = aave_out = ptokens_out = Hash.new
    
    # With investment of 10,000, have 2000; need 5000
    stable_in = {'USDC' => 2000, 'DAI' => 500, 'TCAD' => 5000}
    stable_out = {'USDC' => 0.2, 'DAI' => 0.05, 'TCAD' => 0.5}
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Enough stable coins'"
    if 3 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @errors
      raise '6'
    end

    # Short USDC
    stable_in = {'USDC' => 2000, 'DAI' => 500, 'TCAD' => 5000}
    stable_out = {'USDC' => 0.5, 'DAI' => 0.05, 'TCAD' => 0.5}
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Short USDC'"
    if 2 == @disposition.count and 1 == @errors.count and @ptoken_errors.empty?
      passed += 1
      puts @disposition
      puts @errors
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '7'
    end

    # Take from DAI to make up USDC shortfall
    stable_in = {'USDC' => 2000, 'DAI' => 5000, 'TCAD' => 5000}
    stable_out = {'USDC' => 0.5, 'DAI' => 0.05, 'TCAD' => 0.5}
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Borrow between stable coins'"
    if 3 == @disposition.count and 2 == @disposition['USDC'].count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '8'
    end

    # Craziness
    stable_in = {'USDC' => 20000}
    stable_out = {'USDC' => 0.5, 'DAI' => 0.05, 'TCAD' => 0.5}
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Craziness'"
    if 3 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '9'
    end
    
    # AAVE test cases
    # 1a/b - we need an aToken (stable/crypto), and have enough - just use it
    stable_in = crypto_in = ptokens_in = Hash.new
    stable_out = crypto_out = ptokens_out = Hash.new
    
    # Should have enough
    aave_in = {'aWBTC' => 1, 'aDAI' => 5000}
    aave_out = {'aWBTC' => 0.5, 'aDAI' => 0.5}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Have enough AAVE'"
    if 2 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '10'
    end

    # 2a/b - we need an aToken, and don't have it, or the base token, or ETH - fail
    # Should NOT have enough
    aave_in = {'aWBTC' => 0.1, 'aDAI' => 50}
    aave_out = {'aWBTC' => 0.5, 'aDAI' => 0.5}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Don't have enough AAVE'"
    if 2 == @disposition.count and 2 == @errors.count and @ptoken_errors.empty?
      passed += 1
      puts @disposition
      puts @errors
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '11'
    end

    # 3a/b - we need an aToken, don't have any, but we have the base token - deposit the base token (check balance reduced)
    aave_in = ptokens_in = Hash.new
    stable_out = crypto_out = ptokens_out = Hash.new
    
    crypto_in = {'WBTC' => 0.6}
    stable_in = {'DAI' => 500}
    aave_out = {'aWBTC' => 0.5, 'aDAI' => 0.05}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Don't have enough AAVE, but have base token'"
    if 2 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
      puts @errors
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '12'
    end

    # 4a/b - we need an aToken, have some but not enough; have enough of the base token - use aTokens, plus deposit the shortfall of base token (balance reduced)
    crypto_in = {'WBTC' => 0.6}
    aave_in = {'aWBTC' => 0.02, 'aDAI' => 200}
    stable_in = {'DAI' => 500}
    aave_out = {'aWBTC' => 0.5, 'aDAI' => 0.07}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Use AAVE + base token; still short'"
    if 2 == @disposition.count and 2 == @disposition['aWBTC'].count and 1 == @errors.count and @ptoken_errors.empty?
      passed += 1
      puts @disposition
      puts @errors
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '13'
    end

    # 5a/b - we need an aToken, have some but not enough; don't have enough of the base token, but have ETH - deposit ETH for the aToken (balance reduced)
    crypto_in = {'WBTC' => 0.6, 'ETH' => 5}
    aave_in = {'aWBTC' => 0.02, 'aDAI' => 200}
    stable_in = {'DAI' => 500}
    aave_out = {'aWBTC' => 0.5, 'aDAI' => 0.07}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Use AAVE + base token; fallback to ETH'"
    if 2 == @disposition.count and 2 == @disposition['aWBTC'].count and 2 == @disposition['aDAI'].count and 
       @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
      puts @errors
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '14'
    end
    
    # Crypto test cases
    # 1 Have some shortfalls, and no stable coins
    stable_in = ptokens_in = aave_in = Hash.new
    stable_out = ptokens_out = aave_out = Hash.new
    crypto_in = {'ETH' => 24.5, 'MKR' => 0.5, 'LINK' => 2800}
    crypto_out = {'ETH' => 0.05, 'MKR' => 0.05, 'LINK' => 0.1}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Almost enough Crypto'"
    if 2 == @disposition.count and 1 == @errors.count and @ptoken_errors.empty?
      passed += 1
      puts @disposition
      puts @errors
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '15'
    end

    # 2 Have many tokens, enough of each
    crypto_in = {'ETH' => 24.5, 'MKR' => 2.5, 'LINK' => 2800}
    crypto_out = {'ETH' => 0.05, 'MKR' => 0.05, 'LINK' => 0.1}

    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'Enough Crypto'"
    if 3 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '16'
    end

    # 3 Have many tokens, no crypto, and just a big pile of USDS - should buy them all
    crypto_in = Hash.new
    crypto_out = {'ETH' => 0.05, 'MKR' => 0.05, 'LINK' => 0.1}
    stable_in = {'USDC' => 500, 'DAI' => 500, 'TCAD' => 1000}
    
    @disposition, @errors, @ptoken_errors = calculate_internal(stable_in, crypto_in, ptokens_in, aave_in,
                                                               stable_out, crypto_out, ptokens_out, aave_out)
    
    puts "Running 'No Crypto, buy with stable coins'"
    if 3 == @disposition.count and @errors.empty? and @ptoken_errors.empty?
      passed += 1
      puts @disposition
    else
      failed += 1
      puts @disposition
      puts @errors
      raise '17'
    end
    
    puts "Passed: #{passed}"
    puts "Failed: #{failed}"
  end
  
private
  def calculate_shortfalls(coins_out, coins_in)
    shortfall_amounts = Hash.new
    
    coins_out.each do |coin, pct|
      if Setting::STABLE_COINS.include?(coin)
        price = 1
      else
        price = PriceHistory.latest_price(coin)
      end
      amount_needed = coins_out[coin] * @investment / price
      
      # Use it, if it exists
      if coins_in[coin].to_f >= amount_needed
        # take it
        coins_in[coin] -= amount_needed
        @disposition[coin] = [] unless @disposition.has_key?(coin)
        @disposition[coin].push("Take #{amount_needed.round(2)} from #{coin} balance")
        coin_data = CoinInfo.find_by_coin(coin)
        @encoding[:pool].push({:coin => coin_data.address,
                               :num_tokens => amount_needed,
                               :amount => coin_data.to_wei(amount_needed),
                               :weight => pct,
                               :denorm => Utilities.to_wei(pct*50.0)})
        
        if 0 == coins_in[coin]
          coins_in.delete(coin)
        end          
      else
        shortfall = (amount_needed - coins_in[coin].to_f)
        # short is the USD value, since it will be made up by stablecoins
        # raw_short is the amount of coins
        shortfall_amounts[coin] = {:used => amount_needed - shortfall, 
                                   :short => shortfall * price,
                                   :raw_short => shortfall,
                                   :pct => pct}
      end
    end    
    
    shortfall_amounts
  end
  
  def address_shortfalls(shortfall_amounts, stable_in, slice)
    total_needed = 0
    shortfall_amounts.values.each do |v|
      total_needed += v[:short]
    end
    total_left = stable_in.values.sum
    reconciled = true
    
    if total_needed > total_left
      # Can't do it! No point going further;
      #   there could be residual balances, so further calculations wouldn't be right
      reconciled = false
      shortfall_amounts.each do |coin, short|
        amount = short[:short].round(2)
        if Setting::STABLE_COINS.include?(coin)
          @errors.push("Short #{amount} #{coin} in #{slice} allocation")          
        else
          @errors.push("Short $#{amount} (#{short[:raw_short].round(2)}) of #{coin} in #{slice} allocation")          
        end
      end
    else
      # We need to address all the shortfalls
      # Go through the shortfalls from smallest to largest
      # Go through the stable_in coins from largest to smallest
      shortfall_amounts.sort_by { |k, v| v[:short] }.each do |coin_out, short|
        coin_data = CoinInfo.find_by_coin(coin_out)
        @encoding[:pool].push({:coin => coin_data.address,
                               :num_tokens => short[:raw_short],
                               :amount => coin_data.to_wei(short[:raw_short]),
                               :weight => short[:pct],
                               :denorm => Utilities.to_wei(short[:pct]*50.0) })

        stable_in.sort_by { |k, v| -v }.each do |coin_in, balance|
          if balance >= short[:short]
            stable_in[coin_in] -= short[:short]
            @disposition[coin_out] = [] unless @disposition.has_key?(coin_out)
            
            if short[:used] > 0
              @disposition[coin_out].push("Take #{short[:used].round(2)} from #{coin_out} balance")
            end

            @disposition[coin_out].push("Uniswap #{short[:short].round(2)} #{coin_in} for #{coin_out}")
            src_coin = CoinInfo.find_by_coin(coin_in)
            dest_coin = CoinInfo.find_by_coin(coin_out)
            # We are swapping the *amount* of coins, not the dollar value, so use raw_short
            @encoding[:transforms].push({:method => 'Uniswap', 
                                         :src_coin => src_coin.address,
                                         :dest_coin => dest_coin.address,
                                         :num_tokens => short[:short],
                                         :amount => src_coin.to_wei(short[:short]) })
            # This shortfall has been met, so stop
            break
          elsif balance.round > 0
            # Take as much as we can, and keep going - we have stable_in[coin_in] left
            #   Swap that number of coins for balance USD of the stablecoin
            amount_src_coin_left = stable_in[coin_in]
            stable_in[coin_in] = 0
            @disposition[coin_out] = [] unless @disposition.has_key?(coin_out)
            @disposition[coin_out].push("Uniswap #{balance} #{coin_in} for #{coin_out}")
            src_coin = CoinInfo.find_by_coin(coin_in)
            dest_coin = CoinInfo.find_by_coin(coin_out)
            @encoding[:transforms].push({:method => 'Uniswap', 
                                         :src_coin => src_coin.address,
                                         :dest_coin => dest_coin.address,
                                         :num_tokens => amount_src_coin_left,
                                         :amount => src_coin.to_wei(amount_src_coin_left) })
          end
        end
      end
      
      # Delete any stable_in that have zero balances
      to_delete = []
      stable_in.each do |coin, balance|
        to_delete.push(coin) if 0 == balance
      end  
      to_delete.each do |coin|
        stable_in.delete(coin)
      end
    end    
    
    reconciled
  end
    
  def build_primary_series
    # Primary series is Gold, Crypto, Cash, Equities
    sections = []

    sections.push({:desc => 'Gold', :name => @disposition[Setting::GOLD], :y => @pie.pct_gold, :drilldown => nil}) if @pie.pct_gold > 0
    sections.push({:desc => 'Crypto', :name => 'Crypto', :y => @pie.pct_crypto, :drilldown => 'Crypto'}) if @pie.pct_crypto > 0
    sections.push({:desc => 'Cash', :name => 'Cash', :y => @pie.pct_cash, :drilldown => 'Cash'}) if @pie.pct_cash > 0
    sections.push({:desc => 'Equities', :name => @disposition[@pie.uma_collateral].join(';<br>').html_safe, :y => @pie.pct_equities, :drilldown => nil}) if @pie.pct_equities > 0
    
    {:name => 'Allocation',
     :colorByPoint => true,
     :data => sections}
  end
  
  def build_drilldown_series(disposition)
    series = []
    
    if @pie.pct_crypto > 0
      data = []
      
      Setting.crypto_currency_range.each do |idx|
        currency = @pie.crypto.currency_name(idx)
        if disposition.has_key?(currency)
          label = disposition[currency].join(';<br>').html_safe
          data.push([label, @pie.crypto.currency_pct(idx)])
        end
      end
        
      series.push({:name => 'Crypto',:id => 'Crypto', :data => data})
    end
    
    if @pie.pct_cash > 0
      data = []

      Setting.stablecoin_range.each do |idx|
        currency = @pie.stable_coin.currency_name(idx)
        if disposition.has_key?(currency)
          label = disposition[currency].join(';<br>').html_safe
          data.push([label, @pie.stable_coin.currency_pct(idx)])
        end
      end
      
      series.push({:name => 'Cash',:id => 'Cash', :data => data})
    end
        
    series
  end    
end
