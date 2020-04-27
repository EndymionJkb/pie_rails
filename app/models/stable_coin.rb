# == Schema Information
#
# Table name: stable_coins
#
#  id         :bigint           not null, primary key
#  pie_id     :bigint
#  pct_curr1  :integer
#  pct_curr2  :integer
#  pct_curr3  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class StableCoin < ApplicationRecord
  belongs_to :pie
  
  SUPPORTED_CURRENCIES = ['USDC', 'DAI', 'USDT']

  DEFAULT_PCT_CURR1 = 34
  DEFAULT_PCT_CURR2 = 33
  DEFAULT_PCT_CURR3 = 33
  
  validates_numericality_of :pct_curr1, :pct_curr2, :pct_curr3, :only_integer => true,
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100

  def currency_name(idx)
    SUPPORTED_CURRENCIES[idx]
  end
  
  def reset
    self.update_attributes(:pct_curr1 => DEFAULT_PCT_CURR1,
                           :pct_curr2 => DEFAULT_PCT_CURR2,
                           :pct_curr3 => DEFAULT_PCT_CURR3)
  end
end
