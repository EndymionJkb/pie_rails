require 'utilities'

class PieCalculator
  include Utilities
  
  STARTING_VALUE = 10000

  @pie = nil
  @performance = nil
  
  def initialize(pie)
    @pie = pie
    @performance = pie.performance.nil? ? Hash.new : YAML::load(pie.performance)
  end
  
  def calculate
    raise 'Subclass Responsibility!'
  end
  
  def save
    @pie.update_attribute(:performance, YAML::dump(@performance))
  end 

protected
  def calculate_initial_amount(coin, start_date, pct)
    puts "Initial amount of #{coin}"
    investment = STARTING_VALUE * pct
    puts "#{investment} = #{STARTING_VALUE} * #{pct}"
    start_date = PriceHistory.where(:coin => coin).where('date <= ?', start_date).maximum(:date)
    # Can happen if the data start late
    if start_date.nil?
      start_date = PriceHistory.where(:coin => coin).minimum(:date)
    end

    return [investment, investment / PriceHistory.where(:coin => coin, :date => start_date).first.price]
  end
end

class PieBacktestCalculator < PieCalculator
  # Rebalance daily
  # Create :backtest_return and :backtest_ts (time series for the chart)
  def calculate
    # start 1 year back
    end_date = PriceHistory.all.maximum(:date)
    start_date = PriceHistory.where('date >= ?', end_date - 1.year).minimum(:date)
    # In case a price is missing, use the latest one known (e.g., stock prices over the weekend)
    last_prices = {}
    last_shares = {}
    ref_percentages = {}
    value_yesterday = STARTING_VALUE
    has_gold = false
    has_crypto = false
    has_equity = false
    # Don't rebalance cash
    fixed_cash = 0
    settings = Setting.first
    
    if @pie.pct_gold > 0
      has_gold = true
      
      ref_percentages[Setting::GOLD] = @pie.pct_gold.to_f / 100
      start_date = PriceHistory.where(:coin => Setting::GOLD).where('date <= ?', start_date).maximum(:date)
      price = PriceHistory.where(:coin => Setting::GOLD, :date => start_date).first.price
      last_prices[Setting::GOLD] = price
      last_shares[Setting::GOLD] = STARTING_VALUE * ref_percentages[Setting::GOLD] / price
    end
    
    if @pie.pct_crypto > 0
      has_crypto = true      
      crypto = @pie.crypto
      
      settings.crypto_currency_range.each do |idx|
        if crypto.currency_pct(idx) > 0
          currency = settings.crypto_currency_name(idx)
          
          ref_percentages[currency] = @pie.pct_crypto.to_f / 100 * crypto.currency_pct(idx).to_f / 100
          start_date = PriceHistory.where(:coin => currency).where('date <= ?', start_date).maximum(:date)
          # Can happen if data start late
          if start_date.nil?
            start_date = PriceHistory.where(:coin => currency).minimum(:date)
          end
          
          price = PriceHistory.where(:coin => currency, :date => start_date).first.price
          
          last_prices[currency] = price
          last_shares[currency] = STARTING_VALUE * ref_percentages[currency] / price          
        end
      end
    end
    
    if @pie.pct_cash > 0
      cash = @pie.stable_coin
      fixed_cash = STARTING_VALUE * @pie.pct_cash / 100

      settings.stablecoin_range.each do |idx|
        if cash.currency_pct(idx) > 0
          curr = settings.stablecoin_name(idx)
          
          ref_percentages[curr] = cash.currency_pct(idx).to_f / 100 * @pie.pct_cash.to_f / 100
          last_prices[curr] = 1
          last_shares[curr] = STARTING_VALUE * ref_percentages[curr]
        end
      end
    end
    
    if @pie.pct_equities > 0
      investment = STARTING_VALUE * @pie.pct_equities.to_f / 100
      total_slices = @pie.etfs.count + @pie.stocks.count
      if total_slices > 0
        has_equity = true
        
        reference_pct = @pie.pct_equities.to_f / 100 / total_slices
        investment /= total_slices.to_f
        @pie.etfs.each do |etf|
          # Need to find the price a year ago
          starting_etf_date = PriceHistory.where(:coin => etf.ticker).where('date <= ?', start_date).maximum(:date)
          starting_etf = PriceHistory.where(:coin => etf.ticker, :date => starting_etf_date).first
          
          ref_percentages[etf.ticker] = reference_pct
          last_prices[etf.ticker] = starting_etf.price
          last_shares[etf.ticker] = STARTING_VALUE * reference_pct / starting_etf.price
        end          
        @pie.stocks.each do |stock|
          # Need to find the price a year ago
          starting_stock_date = PriceHistory.where(:coin => stock.cca_id).where('date <= ?', start_date).maximum(:date)
          starting_stock = PriceHistory.where(:coin => stock.cca_id, :date => starting_stock_date).first
          
          ref_percentages[stock.cca_id] = reference_pct
          last_prices[stock.cca_id] = starting_stock.price
          last_shares[stock.cca_id] = STARTING_VALUE * reference_pct / starting_stock.price
        end
      end
    end
    
    # ref_percentages, last_prices, and last_shares have the starting values.
    # Iterate over each day, and rebalance
        
    # So we need to rebalance every day, and track the pct difference in the overall value
    # We plot the value each day, and use the pct differences to compute the return
    # Example:
    # PAXG 2000, 1.5 (1333.33 price)  36.36%
    # USDC 500, 500  (1.0 price)       9.09%
    # IWV 3000, 28.5 (105.26 price)   54.54%
    # Total value on day 1 is 5500
    # Day 2 - PAXG is 1358, IWV is 103.88
    # PAXG value = 1.5*1358 = 2037   (37.05%)
    # USDC value = 500               (9.09%)
    # IWV value = 28.5*103.88 = 2960.58  (53.85%)
    # Total value = 5497.58
    # So gold is a little too high, and the stock is a little too low
    # 36.36% of 5497.58 is 1998.92, which is 1.472, so we need to sell 0.028 PAXG
    # New PAXG = 1.472, $38.024 balance
    # 54.54% of 5497.58 is 2998.38, or 28.863 shares. Need to buy .363 - $37.70
    # So new IWV is 28.863  
    dates = PriceHistory.where('date > ?', start_date).order(:date).pluck(:date).uniq
    # Array of [timestamp,value] arrays, for the backtest line chart; value is the total account value
    graph_points = []
    # Array of pct change from one day to the next, used for computing total return
    pct_change = []
    # Keep track of the "tracking error"
    rebalance_amounts = []
    
    dates.each do |day|
      # Do a single query per day - not one for each commodity!
      today_prices = Hash.new
      PriceHistory.where(:date => day).each do |p|
        today_prices[p.coin] = p.price
      end
      
      # Accumulate pie value today (start with any cash value)
      value_today = fixed_cash
      daily_rebalance = 0
      
      # First recalculate the total value of the pie using new prices (value_today), and put that in graph_points
      # Compute the pct_change, and update value_yesterday
      # Update num_shares for each holding - ref_pct[holding] * value_today/price_today = new_shares
      if has_gold
        # Fall back to last price if it's not present today
        if today_prices[Setting::GOLD].nil?
          price = last_prices[Setting::GOLD]
        else
          price = today_prices[Setting::GOLD]
          last_prices[Setting::GOLD] = price
        end
        
        value_today += last_shares[Setting::GOLD] * price
      end
      
      if has_crypto
        crypto = @pie.crypto
        
        settings.crypto_currency_range.each do |idx|
          if crypto.currency_pct(idx) > 0
            currency = settings.crypto_currency_name(idx)
            
            if today_prices[currency].nil?
              price = last_prices[currency]
            else
              price = today_prices[currency]
              last_prices[currency] = price
            end
            
            value_today += last_shares[currency] * price
          end
        end
      end
            
      if has_equity
        @pie.etfs.map(&:ticker).each do |ticker|
          if today_prices[ticker].nil?
            price = last_prices[ticker]
          else
            price = today_prices[ticker]
            last_prices[ticker] = price
          end
        
          value_today += last_shares[ticker] * price
        end 
        
        @pie.stocks.map(&:cca_id).each do |cca_id|
          if today_prices[cca_id].nil?
            price = last_prices[cca_id]
          else
            price = today_prices[cca_id]
            last_prices[cca_id] = price
          end
        
          value_today += last_shares[cca_id] * price
        end                  
      end
      
      # value_today has the current total - update graph and pct_diff structures
      timestamp = "Date.UTC(#{day.year},#{day.month - 1},#{day.day})"
      graph_points.push([timestamp, value_today.to_f.round(2)])
      # Array of pct change from one day to the next, used for computing total return
      pct_change.push(((value_today - value_yesterday)/value_yesterday).round(2))
      # Update for the next day
      value_yesterday = value_today
      
      # Now update the share values
      if has_gold
        # Update num_shares for each holding - ref_pct[holding] * value_today/price_today = new_shares
        # last_prices has already been updated to today's price
        old_shares = last_shares[Setting::GOLD]
        last_shares[Setting::GOLD] = ref_percentages[Setting::GOLD] * value_today / last_prices[Setting::GOLD]
        diff = (last_shares[Setting::GOLD] - old_shares) * last_prices[Setting::GOLD]
        daily_rebalance += diff
      end
      
      if has_crypto
        crypto = @pie.crypto
        
        settings.crypto_currency_range.each do |idx|
          if crypto.currency_pct(idx) > 0
            currency = settings.crypto_currency_name(idx)
            
            old_shares = last_shares[currency]
            last_shares[currency] = ref_percentages[currency] * value_today / last_prices[currency]
            diff = (last_shares[currency] - old_shares) * last_prices[currency]
            daily_rebalance += diff          
          end
        end
      end
            
      if has_equity
        @pie.etfs.map(&:ticker).each do |ticker|
          old_shares = last_shares[ticker]
          last_shares[ticker] = ref_percentages[ticker] * value_today / last_prices[ticker]
          diff = (last_shares[ticker] - old_shares) * last_prices[ticker]
          daily_rebalance += diff          
        end 
       
        @pie.stocks.map(&:cca_id).each do |cca_id|
          old_shares = last_shares[cca_id]
          last_shares[cca_id] = ref_percentages[cca_id] * value_today / last_prices[cca_id]
          diff = (last_shares[cca_id] - old_shares) * last_prices[cca_id]
          daily_rebalance += diff          
        end                  
      end
      
      rebalance_amounts.push(["Date.UTC(#{day.year},#{day.month - 1},#{day.day})", daily_rebalance.to_f.round(2)])
    end  
    
    @performance[:backtest_ts] = graph_points
    @performance[:backtest_return] = Utilities.geometric_sum(pct_change).round(4)
    @performance[:backtest_rebalance] = rebalance_amounts
  end
end

class PieReturnsCalculator < PieCalculator
  @periods = nil

  # Periods is an array of months
  def initialize(pie, periods)
    super(pie)
    
    @periods = periods
  end

  # Calculate  n-month return, and add to :returns => {3 => 2.43, 6 => -2.43}
  def calculate
    settings = Setting.first
    
    @periods.each do |period|
      investments = Hash.new
      # total_return is the sum of the individual returns
      # For instance, PAXG 3mo return is the geometric sum of all the price differences over the period
      # final_value = initial_value * (1 + return/100)
            
      # investments[asset] = [initial_value, num_shares, cumulative_return]      
      # Start by figuring out how much of each investment you would have, given the starting investment
      start_date = PriceHistory.all.maximum(:date) - period.months
      
      if @pie.pct_gold > 0
        investments[Setting::GOLD] = calculate_initial_amount(Setting::GOLD, start_date, @pie.pct_gold.to_f / 100)
        
        gold_return = Utilities.geometric_sum(PriceHistory.where(:coin => Setting::GOLD).where('date >= ?', start_date).map(&:pct_change))
        investments[Setting::GOLD].push(gold_return.round(4))
      end
      
      if @pie.pct_crypto > 0
        crypto = @pie.crypto
       
        settings.crypto_currency_range.each do |idx|
          if crypto.currency_pct(idx) > 0
            currency = settings.crypto_currency_name(idx)
            
            investments[currency] = calculate_initial_amount(currency, start_date, @pie.pct_crypto.to_f / 100 * crypto.currency_pct(idx).to_f / 100)
            
            coin_return = Utilities.geometric_sum(PriceHistory.where(:coin => currency).where('date >= ?', start_date).map(&:pct_change))
            investments[currency].push(coin_return.round(4))
          end
        end
      end
      
      if @pie.pct_cash > 0
        cash = @pie.stable_coin
        
        settings.stablecoin_range.each do |idx|
          if cash.currency_pct(idx) > 0
            curr = settings.stablecoin_name(idx)
            
            value = cash.currency_pct(idx).to_f / 100 * @pie.pct_cash.to_f / 100 * STARTING_VALUE
            # Assume 0 return
            investments[curr] = [value, value, 0]
          end
        end
      end
      
      if @pie.pct_equities > 0
        investment = STARTING_VALUE * @pie.pct_equities.to_f / 100
        total_slices = @pie.etfs.count + @pie.stocks.count
        if total_slices > 0
          investment /= total_slices.to_f
           @pie.etfs.each do |etf|
            case period
            when 1
              etf_return = etf.m1_return
            when 3
              etf_return = etf.m3_return
            when 6
              etf_return = etf.m6_return
            when 12
              etf_return = etf.y1_return
            else
              raise 'Invalid period for return calculation'
            end              
           # Technically this price isn't right - it's the current price, not the starting price; but we're not using it anyway
           investments[etf.ticker] = [investment, investment / etf.price, etf_return]
          end          
          @pie.stocks.each do |stock|
            case period
            when 1
              stock_return = stock.m1_return
            when 3
              stock_return = stock.m3_return
            when 6
              stock_return = stock.m6_return
            when 12
              stock_return = stock.y1_return
            else
              raise 'Invalid period for return calculation'
            end              
            # Technically this price isn't right - it's the current price, not the starting price; but we're not using it anyway
            investments[stock.company_name] = [investment, investment / stock.price, stock_return]           
          end
        end
      end
      
      # investments[asset] = [initial_value, num_shares, cumulative_return]      
      total_return = 0
      final_value = 0
      investments.keys.each do |asset|
        total_return += investments[asset][2]
        final_value += investments[asset][0] * (1 + investments[asset][2]/100)
      end
      
      @performance[:base_returns] = Hash.new unless @performance.has_key?(:base_returns)
      @performance[:base_returns][period] = {:total_return => total_return, :final_value => final_value}
    end   
  end
end
