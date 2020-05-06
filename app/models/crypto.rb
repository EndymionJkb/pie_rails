# == Schema Information
#
# Table name: cryptos
#
#  id         :bigint           not null, primary key
#  pie_id     :bigint
#  pct_curr1  :integer
#  pct_curr2  :integer
#  pct_curr3  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Crypto < ApplicationRecord
  belongs_to :pie
  
  DEFAULT_PCT_CURR1 = 34
  DEFAULT_PCT_CURR2 = 33
  DEFAULT_PCT_CURR3 = 33

  validates_numericality_of :pct_curr1, :pct_curr2, :pct_curr3, :only_integer => true,
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
                            
  def currency_name(idx)
    Setting.first.crypto_currency_name(idx)
  end

  def currency_pct(idx)
    case idx
      when 0
        self.pct_curr1
      when 1
        self.pct_curr2
      when 2
        self.pct_curr3
      else
        raise 'Invalid currency index'
    end
  end

  def reset
    self.update_attributes(:pct_curr1 => DEFAULT_PCT_CURR1,
                           :pct_curr2 => DEFAULT_PCT_CURR2,
                           :pct_curr3 => DEFAULT_PCT_CURR3)
  end
end
