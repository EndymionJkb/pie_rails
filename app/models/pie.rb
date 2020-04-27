# == Schema Information
#
# Table name: pies
#
#  id           :bigint           not null, primary key
#  user_id      :bigint
#  pct_gold     :integer
#  pct_crypto   :integer
#  pct_cash     :integer
#  pct_equities :integer
#  name         :string(32)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Pie < ApplicationRecord
  belongs_to :user
  
  DEFAULT_PCT_GOLD = 25
  DEFAULT_PCT_CRYPTO = 25
  DEFAULT_PCT_CASH = 25
  DEFAULT_PCT_EQUITIES = 25
  
  has_one :crypto
  has_one :stable_coin
  
  accepts_nested_attributes_for :crypto
  accepts_nested_attributes_for :stable_coin
  
  validates_numericality_of :pct_gold, :pct_crypto, :pct_cash, :pct_equities, :only_integer => true,
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
end
