require 'csv'

namespace :db do
  desc "Upload rest of the prices (AAVE)"
  task :aave_coins => :environment do
    # If we need aWBTC and don't have any, look for WBTC
    PriceHistory.where(:coin => 'WBTC').delete_all
    last_price = nil
    PriceHistory.where(:coin => 'pBTC').order(:date).each do |ph|
      n = ph.dup
      n.coin = 'WBTC'
      if last_price.nil?
        n.pct_change = nil
      else
        n.pct_change = 0 == last_price ? 0 : (n.price - last_price)/last_price
      end
      n.save
      last_price = n.price
    end

    puts "Processing LEND"
    PriceHistory.where(:coin => "LEND").delete_all
    
    CSV.foreach("db/data/lend.csv") do |line|
      date = DateTime.strptime(line[0], '%d-%b-%y') rescue nil
      if date.nil?
        date = DateTime.strptime(line[0], '%m/%d/%y') rescue nil
      end
      next if date.nil?
      
      begin
        PriceHistory.create(:coin => 'LEND',
                            :date => date,
                            :price => line[1].to_f)
      rescue Exception => ex
        puts ex.message
      end
    end
  end  
end
