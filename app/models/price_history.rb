# == Schema Information
#
# Table name: price_histories
#
#  id         :bigint           not null, primary key
#  coin       :string(8)        not null
#  date       :date             not null
#  price      :decimal(8, 2)
#  pct_change :decimal(12, 8)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class PriceHistory < ApplicationRecord
  validates_presence_of :coin, :date, :price
  validates_length_of :coin, :maximum => 8
  validates_numericality_of :price, :greater_than => 0
  
  def self.compute_pct_change
    coins = PriceHistory.all.map(&:coin).uniq
    
    coins.each do |coin|
      last_price = nil
      PriceHistory.where(:coin => coin).order(:date).each do |h|
        if last_price
          h.update_attribute(:pct_change, (h.price - last_price) / last_price)
        end
        
        last_price = h.price
      end
    end
  end
end
