require 'pie_calculator'

# == Schema Information
#
# Table name: pies
#
#  id              :bigint           not null, primary key
#  user_id         :bigint
#  pct_gold        :integer
#  pct_crypto      :integer
#  pct_cash        :integer
#  pct_equities    :integer
#  name            :string(32)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  performance     :text
#  uma_collateral  :string(8)
#  uma_token_name  :string(32)
#  uma_expiry_date :string(16)
#  uma_snapshot    :text
#
class Pie < ApplicationRecord
  belongs_to :user, :optional => true
  
  DEFAULT_PCT_GOLD = 25
  DEFAULT_PCT_CRYPTO = 25
  DEFAULT_PCT_CASH = 25
  DEFAULT_PCT_EQUITIES = 25
  
  MAX_EQUITIES = 8
    
  has_one :crypto
  has_one :stable_coin
  has_one :balancer_pool
  has_one :setting, :through => :user
  has_one :price_identifier
  
  has_and_belongs_to_many :stocks
  has_and_belongs_to_many :etfs
  
  accepts_nested_attributes_for :crypto
  accepts_nested_attributes_for :stable_coin
  
  validates_numericality_of :pct_gold, :pct_crypto, :pct_cash, :pct_equities, :only_integer => true,
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100

  ALLOWED_UMA_COLLATERAL = ['ETH', 'aETH', 'DAI', 'aDAI', 'USDC', 'aUSDC', 'aWBTC', 'aLEND']
  
  # Return as percentage (0-1) - divide by 100 here, so we don't need to in the caller
  # Uses Setting, so none of these _needs methods can be called on a model portfolio (with no user)
  def crypto_needs
    needs = Hash.new
    
    # PAXG is on Uniswap, so it's just a regular crypto
    if self.pct_gold > 0
      needs[Setting::GOLD] = self.pct_gold.to_f / 100
    end
    
    # Add in the coins from the crypto category (if they're not pTokens or aTokens)
    if self.pct_crypto > 0
      Setting.crypto_currency_range.each do |idx|
        name = self.crypto.currency_name(idx)
        # Cryptos can be pTokens or aTokens - and the percentage can also be 0
        unless 0 == self.crypto.currency_pct(idx) or ['a','p'].include?(name[0])
          needs[name] = self.pct_crypto.to_f / 100 * self.crypto.currency_pct(idx).to_f / 100
        end
      end
    end

    # If there are equities, and the collateral is a crypto, add that in as well
    if self.pct_equities > 0 and Setting::CRYPTO_COLLATERAL.include?(self.uma_collateral)
      needs[self.uma_collateral] = self.pct_equities.to_f / 100
    end
        
    needs
  end
  
  def stable_coin_needs
    needs = Hash.new
    
    if self.pct_cash > 0
      Setting.stablecoin_range.each do |idx|
        unless 0 == self.stable_coin.currency_pct(idx)
          needs[self.stable_coin.currency_name(idx)] = self.pct_cash.to_f / 100 * 
                                                       self.stable_coin.currency_pct(idx).to_f / 100
        end
      end
    end

    # If there are equities, and the collateral is a stable coin, add that in as well
    if self.pct_equities > 0 and Setting::STABLE_COLLATERAL.include?(self.uma_collateral)
      needs[self.uma_collateral] = self.pct_equities.to_f / 100
    end
    
    needs
  end
  
  def ptoken_needs
    needs = Hash.new

    if self.pct_crypto > 0
      Setting.crypto_currency_range.each do |idx|
        name = self.crypto.currency_name(idx)
        # Cryptos can be pTokens or aTokens - and the percentage can also be 0
        unless 0 == self.crypto.currency_pct(idx) or 'p' != name[0]
          needs[name] = self.pct_crypto.to_f / 100 * self.crypto.currency_pct(idx).to_f / 100
        end
      end
    end    
    
    # Collateral cannot be a pToken
    
    needs
  end
  
  def aave_needs
    needs = Hash.new

    if self.pct_crypto > 0
      Setting.crypto_currency_range.each do |idx|
        name = self.crypto.currency_name(idx)
        # Cryptos can be pTokens or aTokens - and the percentage can also be 0
        unless 0 == self.crypto.currency_pct(idx) or 'a' != name[0]
          needs[name] = self.pct_crypto.to_f / 100 * self.crypto.currency_pct(idx).to_f / 100
        end
      end
    end    
    
    # If there are equities, and the collateral is an AAVE coin, add that in as well
    if self.pct_equities > 0 and Setting::AAVE_COLLATERAL.include?(self.uma_collateral)
      # Allow for having a crypto that is the same coin as the uma_collateral!
      needs[self.uma_collateral] = 0 unless needs.has_key?(self.uma_collateral)
      
      needs[self.uma_collateral] += self.pct_equities.to_f / 100 * MIN_COLLATERALIZATION
    end
    
    needs    
  end
  
  def backtest_data
    perf = YAML::load(self.performance) rescue Hash.new
    unless perf.has_key?(:backtest_ts)
      pc = PieBacktestCalculator.new(self)
      pc.calculate
      pc.save
      
      perf = YAML::load(self.performance)
    end
     
    return perf[:backtest_ts], perf[:backtest_rebalance], perf[:backtest_return]
  end
                            
  def build_chart
    data = Hash.new
    data[:chart] = {:type => 'pie'}
    data[:title] = {:text => self.name.blank? ? "My Pie" : self.name}
    data[:subtitle] = {:text => 'Click slices to view detailed holdings'}
    data[:plotOptions] = {:series => {:dataLabels => {:enabled => true, :format => '{point.name}<br>{point.y:.1f}%'}}}
    data[:tooltip] = {:headerFormat => '<span style="font-size:11px">{series.name}</span><br>',
                      :pointFormat => '<span style="color:{point.color}">{point.name}</span>: <b>{point.y:.2f}%</b> of total<br/>'}
    data[:series] = [build_primary_series]
    data[:drilldown] = {:series => build_drilldown_series}
    
    data.to_json.html_safe
  end
  
  # Should only get called when there are etfs or stocks
  def equity_graph_data
    data = Hash.new
    equal_weight = 100 / (etfs.count + stocks.count) rescue nil
    
    if equal_weight
      etfs.each do |e|
        data[e.ticker] = equal_weight
      end
      data['stocks'] = equal_weight * stocks.count if stocks.count > 0
    end
    
    data
  end
  
  def backtest_chart_data
    data = Hash.new

    backtest_data, rebalance_data, total_return = self.backtest_data
    data[:chart] = {:zoomType => 'x'}
    data[:title] = {:text => "1 year backtest (daily rebalance)"}
    data[:subtitle] = {:text => "Total return: #{total_return}%"}
    data[:xAxis] = {:type => 'datetime', :dateTimeLabelFormats => {:millisecond => "%m/%d/%y"}}
    data[:yAxis] = [{:title => {:text => 'Total Value'}, :min => PieCalculator::STARTING_VALUE / 2}, 
                    {:opposite => true, :title => {:text => 'Rebalance volume'}}]
    data[:legend] = {:enabled => true}
    data[:plotOptions] = {:area => {:fillColor => {:linearGradient => {:x1 => 0, :y1 => 0, :x2 => 0, :y2 => 1}, 
                                                   :stops => [[0,'#7cb5ec'],
                                                              [1,'#434348']]}
                                                  },
                                    :marker => {:radius => 2},
                                    :lineWidth => 1,
                                    :states => {:hover => {:lineWidth => 1}},
                                    :threshold => nil}
    data[:series] = [{:type => 'area',
                      :name => 'Portfolio Value',
                      :data => backtest_data,
                      :yAxis => 0},
                      {:type => 'area',
                       :name => 'Rebalance Volume',
                       :data => rebalance_data,
                       :yAxis => 1}]
    
    data.to_json.html_safe
  end

  def uma_token_symbol
    "MYDEFIPI-#{self.id}"
  end
  
  def uma_next_month
    if self.uma_expiry_date.blank?
      nil
    else
      next_month = UmaExpiryDate.find_by_ordinal(UmaExpiryDate.find_by_unix(self.uma_expiry_date).ordinal + 1)
      next_month.nil? ? nil : next_month.unix
    end
  end
  
  def uma_expired?
    if self.uma_expiry_date.blank?
      false
    else
      Utilities.current_timestamp > self.uma_expiry_date.to_i
    end    
  end

  # If the argument is given, the adjustment hasn't been made yet (it's a "what if?"; e.g., prior to withdrawal)
  def compute_uma_collateralization(adjustment_override = nil)
    snap = YAML::load(self.uma_snapshot)    
    @total_value = 0
    snap[:slices].keys.each do |key|
      @total_value += snap[:slices][key][:price].to_f * snap[:slices][key][:shares].to_f
    end
    
    adjustment = adjustment_override.nil? ? snap[:net_collateral_adjustment].to_i : adjustment_override
    
    @collateralization = (@total_value + adjustment) / snap[:investment].to_i * 100    
    @progress_class = get_progress_class(@collateralization)
    
    return @collateralization.round(1), @progress_class, (@total_value + adjustment).round(2)
  end
  
  def insufficient_collateral?
    @collateralization, @progress_class, @total_value = self.compute_uma_collateralization
    
    @collateralization < MIN_COLLATERALIZATION * 100
  end
  
private
  def build_primary_series
    # Primary series is Gold, Crypto, Cash, Equities
    sections = []

    sections.push({:name => 'Gold', :y => self.pct_gold, :drilldown => nil}) if self.pct_gold > 0
    sections.push({:name => 'Crypto', :y => self.pct_crypto, :drilldown => 'Crypto'}) if self.pct_crypto > 0
    sections.push({:name => 'Cash', :y => self.pct_cash, :drilldown => 'Cash'}) if self.pct_cash > 0
    sections.push({:name => 'Equities', :y => self.pct_equities, :drilldown => 'Equities'}) if self.pct_equities > 0
    
    {:name => 'Total Allocation',
     :colorByPoint => true,
     :data => sections}
  end
  
  def build_drilldown_series
    series = []
    
    if self.pct_crypto > 0
      data = []
      for idx in Setting.crypto_currency_range do
        data.push([self.crypto.currency_name(idx), self.crypto.currency_pct(idx)]) if self.crypto.currency_pct(idx) > 0
      end
      series.push({:name => 'Crypto',:id => 'Crypto', :data => data})
    end
    
    if self.pct_cash > 0
      data = []
      for idx in Setting.stablecoin_range do
        data.push([self.stable_coin.currency_name(idx), self.stable_coin.currency_pct(idx)]) if self.stable_coin.currency_pct(idx) > 0
      end
      series.push({:name => 'Cash',:id => 'Cash', :data => data})
    end
    
    if self.pct_equities > 0 and (self.etfs.count > 0 or self.stocks.count > 0)
      data = []
      equal_weight = 100.0 / (self.etfs.count + self.stocks.count)
      
      self.etfs.each do |e|
        data.push([e.display_name, equal_weight])      
      end
      self.stocks.each do |s|
        data.push(["#{s.company_name} (#{s.sector})", equal_weight])      
      end

      series.push({:name => 'Equities',:id => 'Equities', :data => data})
    end
    
    series
  end    

  
  def get_progress_class(collateralization)
    if collateralization < MIN_COLLATERALIZATION * 100
      progress_class = 'bg-danger'
    elsif collateralization > (MIN_COLLATERALIZATION + 0.2) * 100
      progress_class = 'bg-success'
    else
      progress_class = 'bg-warning'
    end
    
    progress_class    
  end
end
