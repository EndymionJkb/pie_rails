# == Schema Information
#
# Table name: balancer_pools
#
#  id          :bigint           not null, primary key
#  pie_id      :bigint
#  uma_address :string(42)
#  bp_address  :string(42)
#  allocation  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class BalancerPool < ApplicationRecord
  belongs_to :pie
  
  has_one :user, :through => :pie
  
  # The currencies we will check Metamask balances for
  VALID_CURRENCIES = ['USDC', 'USDT', 'DAI', 'aDAI', 'pBTC', 'ETH', 'LINK', 'BAT',
                      'aETH', 'USDC', 'aUSDC', 'aWBTC', 'aLEND']
  PTOKENS_URL = 'https://dapp.ptokens.io/pbtc-on-eth'
  INITIAL_INVESTMENT = 5000
  
  validates_length_of :uma_address, :bp_address, :is => 42, :allow_nil => true
  
  def balancer_url
    "https://pools.balancer.exchange/#/pool/#{self.bp_address}"
  end

  def self.permitted_coins
    ['ETH', 'USDC', 'pBTC', 'USDT', 'DAI', 'LINK', 'BAT', 'KICK']
  end
end
