class BalanceCalculator
  @graph = nil
  @pie = nil
  @starting_coins = nil
  @investment = nil
  
  def initialize(pie, starting_coins, investment)
    @pie = pie
    @starting_coins = starting_coins
    @investment = investment
  end
  
  def calculate
    {:result => false, 
     :errors => [{:needs_pbtc => {:amount => 0.0125,
                                  :address => '14a4aHGFggMCne6AuVszrtiDfSZbcCr51L'}}, 
                 {:msg => 'You are short 0.158 ETH'},
                 {:msg => 'AAVE is unavailable'}]}
  end
  
  def build_chart
    data = Hash.new
    data[:chart] = {:type => 'pie'}
    data[:title] = {:text => "#{@pie.name} Plan"}
    data[:subtitle] = {:text => 'Click slices to view plans for constituents'}
    data[:plotOptions] = {:series => {:dataLabels => {:enabled => true, :format => '{point.name}<br>{point.y:.1f}%'}}}
    data[:tooltip] = {:headerFormat => '<span style="font-size:11px">{series.name}</span><br>',
                      :pointFormat => '<span style="color:{point.color}">{point.desc}</span>: <b>{point.y:.2f}%</b> of total<br/>'}
    data[:series] = [build_primary_series]
    data[:drilldown] = {:series => build_drilldown_series}
    
    data.to_json.html_safe
  end
  
private
  def build_primary_series
    # Primary series is Gold, Crypto, Cash, Equities
    sections = []

    sections.push({:desc => 'Gold', :name => 'Uniswap 1705 DAI for 1 PAXG', :y => @pie.pct_gold, :drilldown => nil}) if @pie.pct_gold > 0
    sections.push({:desc => 'Crypto', :name => 'Crypto', :y => @pie.pct_crypto, :drilldown => 'Crypto'}) if @pie.pct_crypto > 0
    sections.push({:desc => 'Cash', :name => 'Cash', :y => @pie.pct_cash, :drilldown => 'Cash'}) if @pie.pct_cash > 0
    sections.push({:desc => 'Equities', :name => 'Uniswap 850 DAI for 8500 aDAI', :y => @pie.pct_equities, :drilldown => nil}) if @pie.pct_equities > 0
    
    {:name => 'Allocation',
     :colorByPoint => true,
     :data => sections}
  end
  
  def build_drilldown_series
    series = []
    
    if @pie.pct_crypto > 0
      data = []
      data.push(['Use 0.125 pBTC from balance', @pie.crypto.currency_pct(0)])
      data.push(['Use 4.147 ETH from balance', @pie.crypto.currency_pct(1)])
      data.push(['Uniswap 1250.2 USDC for 78.4 LINK', @pie.crypto.currency_pct(1)])
      #for idx in 0..2 do
      #  data.push([@pie.crypto.currency_name(idx), @pie.crypto.currency_pct(idx)]) if @pie.crypto.currency_pct(idx) > 0
      #end
      series.push({:name => 'Crypto',:id => 'Crypto', :data => data})
    end
    
    if @pie.pct_cash > 0
      data = []
      data.push(['Use 1250 USDC from balance', @pie.crypto.currency_pct(0)])
      data.push(['Use 850 DAI from balance', @pie.crypto.currency_pct(1)])
      data.push(['Uniswap 1250.25 USDC for 1250 USDT', @pie.crypto.currency_pct(1)])
      #for idx in 0..2 do
      #  data.push([@pie.stable_coin.currency_name(idx), @pie.stable_coin.currency_pct(idx)]) if @pie.stable_coin.currency_pct(idx) > 0
      #end
      series.push({:name => 'Cash',:id => 'Cash', :data => data})
    end
        
    series
  end    
end
