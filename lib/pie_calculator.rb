require 'utilities'

class PieCalculator
  include Utilities
  
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
end

class PieReturnsCalculator < PieCalculator
  STARTING_VALUE = 10000
  @periods = nil

  # Periods is an array of months
  def initialize(pie, periods)
    super(pie)
    
    @periods = periods
  end

  # Calculate  n-month return, and add to :returns => {3 => 2.43, 6 => -2.43}
  def calculate
    @periods.each do |period|
      investments = Hash.new
      # total_return is the sum of the individual returns
      # For instance, PAXG 3mo return is the geometric sum of all the price differences over the period
      # final_value = initial_value * (1 + return/100)
            
      # investments[asset] = [initial_value, num_shares, cumulative_return]      
      # Start by figuring out how much of each investment you would have, given the starting investment
      start_date = PriceHistory.all.maximum(:date) - period.months
      
      if @pie.pct_gold > 0
        investments['PAXG'] = calculate_initial_amount('PAXG', start_date, @pie.pct_gold.to_f / 100)
        
        gold_return = Utilities.geometric_sum(PriceHistory.where(:coin => 'PAXG').where('date >= ?', start_date).map(&:pct_change))
        investments['PAXG'].push(gold_return.round(4))
        #final_gold_value = investments['PAXG'][0] * (1 + gold_return/100)
       end
      
      if @pie.pct_crypto > 0
        crypto = @pie.crypto
        idx = 0
        Crypto::SUPPORTED_CURRENCIES.each do |curr|
          if crypto.currency_pct(idx) > 0
            currency = Crypto::SUPPORTED_CURRENCIES[idx]
            investments[currency] = calculate_initial_amount(currency, start_date, @pie.pct_crypto.to_f / 100 * crypto.currency_pct(idx).to_f / 100)
            
            coin_return = Utilities.geometric_sum(PriceHistory.where(:coin => currency).where('date >= ?', start_date).map(&:pct_change))
            investments[currency].push(coin_return.round(4))
          end
          idx += 1
        end
      end
      
      if @pie.pct_cash > 0
        cash = @pie.stable_coin
        
        idx = 0
        StableCoin::SUPPORTED_CURRENCIES.each do |curr|
          if cash.currency_pct(idx) > 0
            value = cash.currency_pct(idx).to_f / 100 * @pie.pct_cash.to_f / 100 * STARTING_VALUE
            # Assume 0 return
            investments[curr] = [value, value, 0]
          end
          idx += 1
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
            investments[etf.ticker] = [investment, etf.price / investment, etf_return]
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
            investments[stock.company_name] = [investment, stock.price / investment, stock_return]           
          end
        end
      end
      
      puts investments
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
  
private
  def calculate_initial_amount(coin, start_date, pct)
    puts "Initial amount of #{coin}"
    investment = STARTING_VALUE * pct
    puts "#{investment} = #{STARTING_VALUE} * #{pct}"
    start_date = PriceHistory.where(:coin => coin).where('date <= ?', start_date).maximum(:date)
    
    return [investment, investment / PriceHistory.where(:coin => coin, :date => start_date).first.price]
  end
end
