require 'csv'

namespace :db do
  desc "Upload historical ETF and Stock prices for backtesting"
  task :historical_prices => :environment do
    # This assumes there is no ETF named the same as a coin!
    coins = Hash.new
    CSV.foreach("db/data/historical_etf_prices.csv", :headers => true) do |line|
      coins[line[0]] = 1
    end
    coins.each do |coin|
      PriceHistory.where(:coin => coin).delete_all
    end
    
    puts "Processing ETFs"
    CSV.foreach("db/data/historical_etf_prices.csv", :headers => true) do |line|
      date = DateTime.strptime(line[1], '%m/%d/%y') rescue nil
      if date.nil?
        date = DateTime.strptime(line[1], '%Y-%m-%d') rescue nil
      end
      next if date.nil?
      
      begin
        PriceHistory.create(:coin => line[0],
                            :date => date,
                            :price => line[2].to_f)
      rescue Exception => ex
        puts ex.message
      end
    end  

    coins = Hash.new
    CSV.foreach("db/data/historical_stock_prices.csv", :headers => true) do |line|
      coins[line[0]] = 1
    end
    coins.each do |coin|
      PriceHistory.where(:coin => coin).delete_all
    end
    
    puts "Processing Stocks"
    CSV.foreach("db/data/historical_stock_prices.csv", :headers => true) do |line|
      date = DateTime.strptime(line[1], '%Y-%m-%d') rescue nil
      if date.nil?
        date = DateTime.strptime(line[1], '%m/%d/%y') rescue nil
      end
      next if date.nil?
      
      begin
        PriceHistory.create(:coin => line[0],
                            :date => date,
                            :price => line[2].to_f)
      rescue Exception => ex
        puts ex.message
      end
    end  
  
    puts "Computing pct change for returns"
    PriceHistory.compute_pct_change
  end
end
