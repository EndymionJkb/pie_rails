# == Schema Information
#
# Table name: price_histories
#
#  id         :bigint           not null, primary key
#  coin       :string(8)        not null
#  date       :date             not null
#  price      :decimal(8, 2)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class PriceHistory < ApplicationRecord
  validates_presence_of :coin, :date, :price
  validates_length_of :coin, :maximum => 8
  validates_numericality_of :price, :greater_than => 0
end
