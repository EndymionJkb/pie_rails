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
#
class Pie < ApplicationRecord
  belongs_to :user, :optional => true
  
  DEFAULT_PCT_GOLD = 25
  DEFAULT_PCT_CRYPTO = 25
  DEFAULT_PCT_CASH = 25
  DEFAULT_PCT_EQUITIES = 25
  
  MAX_EQUITIES = 8
  
  ALLOWED_UMA_COLLATERAL = ['ETH', 'aETH', 'DAI', 'aDAI', 'USDC', 'aUSDC', 'aWBTC', 'aLEND']
  DEFAULT_COLLATERAL = 'aDAI'
  UMA_EXPIRY_DATES = ['6/1/2020', '7/1/2020', '8/1/2020', '9/1/2020', '10/1/2020', '11/1/2020', '12/1/2020',
                      '1/1/2021', '2/1/2021', '3/1/2021', '4/1/2021', '5/1/2021', '6/1/2021', '7/1/2021']
  DEFAULT_EXPIRY_DATE = '6/1/2020'
  
  has_one :crypto
  has_one :stable_coin
  has_one :balancer_pool
  
  has_and_belongs_to_many :stocks
  has_and_belongs_to_many :etfs
  
  accepts_nested_attributes_for :crypto
  accepts_nested_attributes_for :stable_coin
  
  validates_numericality_of :pct_gold, :pct_crypto, :pct_cash, :pct_equities, :only_integer => true,
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
  
  def amount_pbtc_needed(total_value)
    if self.pct_crypto > 0 and crypto.pct_curr1 > 0
      btc_date = PriceHistory.where(:coin => 'pBTC').maximum(:date)
      price = PriceHistory.where(:coin => 'pBTC', :date => btc_date).first.price
      
      total_value * self.pct_crypto * crypto.pct_curr1 / price
    end
  end
  
  def backtest_data
    perf = YAML::load(self.performance)
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
    "MDPSNX#{self.id}"
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
      for idx in 0..2 do
        data.push([self.crypto.currency_name(idx), self.crypto.currency_pct(idx)]) if self.crypto.currency_pct(idx) > 0
      end
      series.push({:name => 'Crypto',:id => 'Crypto', :data => data})
    end
    
    if self.pct_cash > 0
      data = []
      for idx in 0..2 do
        data.push([self.stable_coin.currency_name(idx), self.stable_coin.currency_pct(idx)]) if self.stable_coin.currency_pct(idx) > 0
      end
      series.push({:name => 'Cash',:id => 'Cash', :data => data})
    end
    
    if self.pct_equities > 0 and (self.etfs.count > 0 or self.stocks.count > 0)
      data = []
      equal_weight = 100.0 / (self.etfs.count + self.stocks.count)
      
      self.etfs.each do |e|
        data.push(["#{e.ticker} (#{e.fund_name})", equal_weight])      
      end
      self.stocks.each do |s|
        data.push(["#{s.company_name} (#{s.sector})", equal_weight])      
      end

      series.push({:name => 'Equities',:id => 'Equities', :data => data})
    end
    
    series
  end    
end
