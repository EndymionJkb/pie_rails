require 'csv'

namespace :db do
  desc "Upload rest of the prices"
  task :alternate_coins => :environment do
    # aWBTC, aLINK
    # Copy pBTC => aWBTC; copy LINK -> aLINK
    PriceHistory.where(:coin => 'aWBTC').delete_all
    last_price = nil
    PriceHistory.where(:coin => 'pBTC').order(:date).each do |ph|
      n = ph.dup
      n.coin = 'aWBTC'
      if last_price.nil?
        n.pct_change = nil
      else
        n.pct_change = 0 == last_price ? 0 : (n.price - last_price)/last_price
      end
      n.save
      last_price = n.price
    end

    last_price = nil
    PriceHistory.where(:coin => 'aLINK').delete_all
    PriceHistory.where(:coin => 'LINK').each do |ph|
      n = ph.dup
      n.coin = 'aLINK'
      n.pct_change = nil
      if last_price.nil?
        n.pct_change = nil
      else
        n.pct_change = 0 == last_price ? 0 : (n.price - last_price)/last_price
      end
      n.save
    end

    ['cro', 'hedg', 'kcs', 'knc', 'leo', 'mco', 'mkr', 'nexo','nmr', 'rep'].each do |coin|
      puts "Processing #{coin}"
      PriceHistory.where(:coin => coin.upcase).delete_all
      
      CSV.foreach("db/data/#{coin}.csv") do |line|
        date = DateTime.strptime(line[0], '%d-%b-%y') rescue nil
        if date.nil?
          date = DateTime.strptime(line[0], '%m/%d/%y') rescue nil
        end
        next if date.nil?
        
        begin
          PriceHistory.create(:coin => coin.upcase,
                              :date => date,
                              :price => line[1].to_f)
        rescue Exception => ex
          puts ex.message
        end
      end  
    end
    
    last_price = nil
    PriceHistory.where(:coin => 'aMKR').delete_all
    PriceHistory.where(:coin => 'MKR').each do |ph|
      n = ph.dup
      n.coin = 'aMKR'
      n.pct_change = nil
      if last_price.nil?
        n.pct_change = nil
      else
        n.pct_change = 0 == last_price ? 0 : (n.price - last_price)/last_price
      end
      n.save
    end
  end
end
