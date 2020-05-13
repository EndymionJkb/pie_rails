require 'csv'
require 'pie_calculator'

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
if 0 == Stock.count
  start_date = Date.new(2020, 3, 31)

  CSV.foreach('db/data/Stocks.csv', :headers => true) do |line|
    Stock.create(:cca_id => line[0].to_i,
                 :run_date => start_date,
                 :company_name => line[1].strip,
                 :sector => line[2].strip,
                 :forecast_e => line[3].to_f,
                 :forecast_s => line[4].to_f,
                 :forecast_g => line[5].to_f,
                 :alpha => line[6].to_f,
                 :m1_return => line[7].to_f,
                 :m3_return => line[8].to_f,
                 :m6_return => line[9].to_f,
                 :y1_return => line[10].to_f,
                 :price => line[11].to_f)
  end  
end

if 0 == Etf.count
  start_date = Date.new(2020, 3, 31)

  CSV.foreach('db/data/ETFs.csv', :headers => true) do |line|
    Etf.create(:cca_id => line[0].to_i,
               :run_date => start_date,
               :ticker => line[1].strip,
               :fund_name => line[2].strip,
               :forecast_e => line[3].to_f,
               :forecast_s => line[4].to_f,
               :forecast_g => line[5].to_f,
               :esg_performance => line[6].to_f,
               :alpha => line[7].to_f,
               :m1_return => line[8].to_f,
               :m3_return => line[9].to_f,
               :m6_return => line[10].to_f,
               :y1_return => line[11].to_f,
               :price => line[12].to_f)
  end  
end

if 0 == PriceHistory.count
  ['pBTC', 'ETH', 'LINK', 'PAXG'].each do |coin|
    puts "Loading #{coin}"
    fname = 'pBTC' == coin ? "BTCPrices.csv" : "#{coin}Prices.csv"
    
    CSV.foreach("db/data/#{fname}", :headers => true) do |line|
      date = DateTime.strptime(line[0], '%d-%b-%y') rescue nil
      if date.nil?
        date = DateTime.strptime(line[0], '%m/%d/%y')
      end
      
      PriceHistory.create(:coin => coin,
                          :date => date,
                          :price => line[1].to_f)
    end  
  end
  
  puts "Computing pct change for returns"
  PriceHistory.compute_pct_change
end

if 0 == Pie.where(:user_id => nil).count
  # Sample pies, with user_id 0
  p = Pie.create(:user_id => 0,
                 :pct_gold => 20,
                 :pct_cash => 50,
                 :pct_crypto => 20,
                 :pct_equities => 10,
                 :name => 'Conservative')
  p.etfs << Etf.where('cca_id IN (?)', [3372, 3250, 3117, 3145])
  p.create_crypto(:pct_curr1 => 50, :pct_curr2 => 50, :pct_curr3 => 0) # BTC, ETH, LINK
  p.create_stable_coin(:pct_curr1 => 50, :pct_curr2 => 0, :pct_curr3 => 50) # USDC, DAI, USDT
  perf = PieReturnsCalculator.new(p, [1, 3, 6, 12])
  perf.calculate
  perf.save
  
  p = Pie.create(:user_id => nil,
                 :pct_gold => 20,
                 :pct_cash => 10,
                 :pct_crypto => 0,
                 :pct_equities => 70,
                 :name => 'Traditional')
  p.etfs << Etf.where('cca_id IN (?)', [3372, 3250, 3117, 3145])
  p.stocks << Stock.where('cca_id IN (?)', [96923, 97269, 99348, 98696])
  p.create_stable_coin(:pct_curr1 => 50, :pct_curr2 => 0, :pct_curr3 => 50) # USDC, DAI, USDT
  perf = PieReturnsCalculator.new(p, [1, 3, 6, 12])
  perf.calculate
  perf.save
  
  p = Pie.create(:user_id => nil,
                 :pct_gold => 0,
                 :pct_cash => 20,
                 :pct_crypto => 50,
                 :pct_equities => 30,
                 :name => 'Growth')
  p.create_crypto(:pct_curr1 => 50, :pct_curr2 => 30, :pct_curr3 => 20) # BTC, ETH, LINK
  p.create_stable_coin(:pct_curr1 => 40, :pct_curr2 => 40, :pct_curr3 => 20) # USDC, DAI, USDT
  p.etfs << Etf.where('cca_id IN (?)', [3372, 3250, 3117, 3145])
  p.stocks << Stock.where('cca_id IN (?)', [96923, 97269, 99348, 98696])
  perf = PieReturnsCalculator.new(p, [1, 3, 6, 12])
  perf.calculate
  perf.save

  p = Pie.create(:user_id => nil,
                 :pct_gold => 0,
                 :pct_cash => 20,
                 :pct_crypto => 80,
                 :pct_equities => 0,
                 :name => 'Crypto Focus')
  p.create_crypto(:pct_curr1 => 40, :pct_curr2 => 30, :pct_curr3 => 30) # BTC, ETH, LINK
  p.create_stable_coin(:pct_curr1 => 20, :pct_curr2 => 80, :pct_curr3 => 0) # USDC, DAI, USDT
  perf = PieReturnsCalculator.new(p, [1, 3, 6, 12])
  perf.calculate
  perf.save

  p = Pie.create(:user_id => nil,
                 :pct_gold => 30,
                 :pct_cash => 50,
                 :pct_crypto => 20,
                 :pct_equities => 0,
                 :name => 'Pandemic!')
  p.create_crypto(:pct_curr1 => 80, :pct_curr2 => 20, :pct_curr3 => 0) # BTC, ETH, LINK
  p.create_stable_coin(:pct_curr1 => 100, :pct_curr2 => 0, :pct_curr3 => 0) # USDC, DAI, USDT
  perf = PieReturnsCalculator.new(p, [1, 3, 6, 12])
  perf.calculate
  perf.save
end

if 0 == CoinInfo.count
  CoinInfo.create(:coin => 'USDC', :address => '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', :decimals => 6)
  CoinInfo.create(:coin => 'USDT', :address => '0xdac17f958d2ee523a2206206994597c13d831ec7', :decimals => 6)
  CoinInfo.create(:coin => 'pBTC', :address => '0x5228a22e72ccc52d415ecfd199f99d0665e7733b')
  CoinInfo.create(:coin => 'DAI', :address => '0x6b175474e89094c44da98b954eedeac495271d0f')
  CoinInfo.create(:coin => 'TUSD', :address => '0x0000000000085d4780B73119b644AE5ecd22b376')
  CoinInfo.create(:coin => 'TCAD', :address => '0x00000100F2A2bd000715001920eB70D229700085')
  CoinInfo.create(:coin => 'TGBP', :address => '0x00000000441378008ea67f4284a57932b1c000a5')
  CoinInfo.create(:coin => 'THKD', :address => '0x0000852600ceb001e08e00bc008be620d60031f2')
  CoinInfo.create(:coin => 'USDS', :address => '0xa4bdb11dc0a2bec88d24a3aa1e6bb17201112ebe', :decimals => 6)
  CoinInfo.create(:coin => 'LINK', :address => '0x514910771af9ca656af840dff83e8264ecf986ca')
  CoinInfo.create(:coin => 'HEDG', :address => '0xf1290473e210b2108a85237fbcd7b6eb42cc654f')
  CoinInfo.create(:coin => 'REP', :address => '0x1985365e9f78359a9B6AD760e32412f4a445E862')
  CoinInfo.create(:coin => 'NMR', :address => '0x1776e1f26f98b1a5df9cd347953a26dd3cb46671')
  CoinInfo.create(:coin => 'LEO', :address => '0x2af5d2ad76741191d15dfe7bf6ac92d4bd912ca3')
  CoinInfo.create(:coin => 'KNC', :address => '0xdd974d5c2e2928dea5f71b9825b8b646686bd200')
  CoinInfo.create(:coin => 'KCS', :address => '0x039b5649a59967e3e936d7471f9c3700100ee1ab', :decimals => 6)
  CoinInfo.create(:coin => 'CRO', :address => '0xa0b73e1ff0b80914ab6fe0444e65848c4c34450b', :decimals => 8)
  CoinInfo.create(:coin => 'NEXO', :address => '0xb62132e35a6c13ee1ee0f84dc5d40bad8d815206')
  CoinInfo.create(:coin => 'MCO', :address => '0xb63b606ac810a52cca15e44bb630fd42d8d1d83d', :decimals => 8)
  CoinInfo.create(:coin => 'aWBTC', :address => '0xFC4B8ED459e00e5400be803A9BB3954234FD50e3', :decimals => 8)
  CoinInfo.create(:coin => 'aMKR', :address => '0x7deB5e830be29F91E298ba5FF1356BB7f8146998')
  CoinInfo.create(:coin => 'aLINK', :address => '0xd3771f28192cc0d78f93a2031a6a7aee6dc0a302') # Defunct?
  CoinInfo.create(:coin => 'PAXG', :address => '0x45804880De22913dAFE09f4980848ECE6EcbAf78')
  CoinInfo.create(:coin => 'aETH', :address => '0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04') # Questionable
  CoinInfo.create(:coin => 'aDAI', :address => '0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d')
  CoinInfo.create(:coin => 'aUSDC', :address => '0x9bA00D6856a4eDF4665BcA2C2309936572473B7E', :decimals => 6)
  CoinInfo.create(:coin => 'aLEND', :address => '0x7D2D3688Df45Ce7C552E19c27e007673da9204B8')
  CoinInfo.create(:coin => 'WBTC', :address => '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599', :decimals => 8)
  CoinInfo.create(:coin => 'MKR', :address => '0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2')
  CoinInfo.create(:coin => 'LEND', :address => '0x80fB784B7eD66730e8b1DBd9820aFD29931aab03')
  # The AAVE address used to mean ETH
  CoinInfo.create(:coin => 'ETH', :address => '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE')
end

