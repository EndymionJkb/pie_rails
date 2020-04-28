require 'csv'

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
                 :y1_return => line[10].to_f)
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
               :benchmark => line[8].to_f)
  end  
end
