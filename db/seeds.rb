require 'csv'

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
if 0 == Stock.count
  CSV.foreach('db/data/Stocks.csv', :headers => true) do |line|
    Stock.create(:company_name => line[0].strip,
                 :sector => line[1].strip,
                 :forecast_e => line[2].to_f,
                 :forecast_s => line[3].to_f,
                 :forecast_g => line[4].to_f,
                 :alpha => line[5].to_f,
                 :m1_return => line[6].to_f,
                 :m3_return => line[7].to_f,
                 :m6_return => line[8].to_f,
                 :y1_return => line[9].to_f)
  end  
end

if 0 == Etf.count
  CSV.foreach('db/data/ETFs.csv', :headers => true) do |line|
    Etf.create(:ticker => line[0].strip,
               :fund_name => line[1].strip,
               :forecast_e => line[2].to_f,
               :forecast_s => line[3].to_f,
               :forecast_g => line[4].to_f,
               :esg_performance => line[5].to_f,
               :alpha => line[6].to_f,
               :benchmark => line[7].to_f)
  end  
end
