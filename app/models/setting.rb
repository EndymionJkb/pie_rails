# == Schema Information
#
# Table name: settings
#
#  id           :bigint           not null, primary key
#  user_id      :bigint
#  e_priority   :integer          not null
#  s_priority   :integer          not null
#  g_priority   :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  focus        :string(32)
#  stable_coins :string
#
class Setting < ApplicationRecord
  DEFAULT_E = 34
  DEFAULT_S = 33
  DEFAULT_G = 33

  LARGE_CAP = 'Large Cap'
  PREDICTION = 'Prediction Market'
  EXCHANGES = 'Exchanges'
  FINANCE = 'Finance'
  INTEREST = 'Interest'
  
  belongs_to :user
  
  validates_numericality_of :e_priority, :s_priority, :g_priority, :only_integer => true, 
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
  validates_length_of :focus, :maximum => 32
  
  def crypto_currency_range
    [0,1,2]
  end
  
  def stablecoin_range
    [0,1,2]
  end
  
  def supported_crypto_currencies
    cryptos = []
    crypto_currency_range.each do |idx|
      cryptos.push(crypto_currency_name(idx))
    end
    
    cryptos
  end
  
  def supported_stablecoins
    coins = []
    stablecoin_range.each do |idx|
      cryptos.push(stablecoin_name(idx))
    end
    
    coins
  end
  
  def stablecoin_selected?(coin)
    coins = self.stable_coins.split(',')
    coins.include?(coin)
  end
  
  def crypto_currency_name(idx)
    case self.focus
    when LARGE_CAP
      case idx
      when 0
        'pBTC'
      when 1
        'ETH'
      when 2
        'LINK'
      else
        raise 'Invalid index'
      end
    when PREDICTION
      case idx
      when 0
        'HEDG'
      when 1
        'REP'
      when 2
        'NMR'
      else
        raise 'Invalid index'
      end
    when EXCHANGES
      case idx
      when 0
        'LEO'
      when 1
        'KNC'
      when 2
        'KCS'
      else
        raise 'Invalid index'
      end
    when FINANCE
      case idx
      when 0
        'CRO'
      when 1
        'NEXO'
      when 2
        'MCO'
      else
        raise 'Invalid index'
      end
    when INTEREST
      case idx
      when 0
        'aWBTC'
      when 1
        'aMKR'
      when 2
        'aLINK'
      else
        raise 'Invalid index'
      end
    else
      raise 'Invalid Focus'
    end
  end
  
  def stablecoin_name(idx)
    coins = self.stable_coins.split(',')

    coins[idx].upcase
  end
end
