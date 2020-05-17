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
  INTEREST = 'Lending'
  CATEGORIES = [LARGE_CAP, PREDICTION, EXCHANGES, FINANCE, INTEREST]
  
  STABLE_COINS = ['USDC', 'DAI', 'USDT', 'TUSD', 'TCAD', 'TAUD', 'TGBP', 'THKD', 'USDS']
  GOLD = 'PAXG'
  
  CRYPTO_COLLATERAL = ['ETH']
  STABLE_COLLATERAL = ['DAI', 'USDC']
  AAVE_COLLATERAL = ['aETH', 'aDAI', 'aUSDC', 'aWBTC', 'aLEND']
  
  ALLOWED_UMA_COLLATERAL = CRYPTO_COLLATERAL + STABLE_COLLATERAL + AAVE_COLLATERAL
  DEFAULT_COLLATERAL = 'aDAI'
  
  belongs_to :user
  
  validates_numericality_of :e_priority, :s_priority, :g_priority, :only_integer => true, 
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
  validates_length_of :focus, :maximum => 32
  
  def self.crypto_currency_range
    [0,1,2]
  end
  
  def self.stablecoin_range
    [0,1,2]
  end
    
  def self.all_currencies
    all = STABLE_COINS.dup + all_cryptos + [GOLD]
    ALLOWED_UMA_COLLATERAL.each do |c|
      all.push(c) unless all.include?(c)
    end
    
    # Check for AAVE counterpart coins!
    to_add = []
    all.each do |coin|
      if 'a' == coin[0]
        base = coin[1,coin.size]
        to_add.push(base) unless all.include?(base)
      end
    end
    
    to_add.each do |coin|
      all.push(coin)
    end
    
    all
  end
  
  def self.all_cryptos
    cryptos = []
    CATEGORIES.each do |cat|
      Setting.crypto_currency_range.each do |idx|
        cryptos.push(Setting.crypto_currency_name(idx, cat))
      end
    end 
    
    cryptos  
  end
  
  # 3 current ones
  def supported_crypto_currencies
    cryptos = []
    crypto_currency_range.each do |idx|
      cryptos.push(crypto_currency_name(idx))
    end
    
    cryptos
  end
  
  # 3 current ones
  def supported_stablecoins
    coins = []
    stablecoin_range.each do |idx|
      coins.push(stablecoin_name(idx))
    end
    
    coins
  end
  
  def stablecoin_selected?(coin)
    coins = self.stable_coins.split(',')
    coins.include?(coin)
  end
  
  def self.crypto_currency_name(idx, focus)
    case focus
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
