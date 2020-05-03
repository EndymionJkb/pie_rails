# == Schema Information
#
# Table name: pies
#
#  id           :bigint           not null, primary key
#  user_id      :bigint
#  pct_gold     :integer
#  pct_crypto   :integer
#  pct_cash     :integer
#  pct_equities :integer
#  name         :string(32)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
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
  
  has_and_belongs_to_many :stocks
  has_and_belongs_to_many :etfs
  
  accepts_nested_attributes_for :crypto
  accepts_nested_attributes_for :stable_coin
  
  validates_numericality_of :pct_gold, :pct_crypto, :pct_cash, :pct_equities, :only_integer => true,
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
                            
  def build_chart
    data = Hash.new
    data[:chart] = {:type => 'pie'}
    data[:title] = {:text => 'My Personal Pie'}
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
      data['stocks'] = equal_weight * stocks.count
    end
    
    data
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
        data.push([self.crypto.currency_name(idx), self.crypto.currency_pct(idx)])
      end
      series.push({:name => 'Crypto',:id => 'Crypto', :data => data})
    end
    
    if self.pct_cash > 0
      data = []
      for idx in 0..2 do
        data.push([self.stable_coin.currency_name(idx), self.stable_coin.currency_pct(idx)])
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
