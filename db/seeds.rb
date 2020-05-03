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
