# == Schema Information
#
# Table name: balancer_pools
#
#  id                   :bigint           not null, primary key
#  pie_id               :bigint
#  uma_address          :string(42)
#  bp_address           :string(42)
#  allocation           :text
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  swaps_completed      :boolean          default(FALSE), not null
#  finalized            :boolean          default(FALSE), not null
#  pending_changes      :text
#  withdrawal_available :datetime
#  pending_withdrawal   :integer
#
class BalancerPool < ApplicationRecord
  belongs_to :pie
  
  has_one :user, :through => :pie
  
  PTOKENS_URL = 'https://dapp.ptokens.io/pbtc-on-eth'
  INITIAL_INVESTMENT = 5000
  
  validates_length_of :uma_address, :bp_address, :is => 42, :allow_nil => true
  validates_inclusion_of :swaps_completed, :finalized, :in => [true, false]
  validates_numericality_of :pending_withdrawal, :only_integer => true, :greater_than => 0, :allow_nil => true
  
  def balancer_url
    "https://pools.balancer.exchange/#/pool/#{self.bp_address}"
  end
end
