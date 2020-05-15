require 'utilities'
# == Schema Information
#
# Table name: coin_infos
#
#  coin       :string(8)        not null, primary key
#  address    :string(42)       not null
#  decimals   :integer          default(18), not null
#  used       :boolean          default(FALSE), not null
#  abi        :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class CoinInfo < ApplicationRecord
  include Utilities
  
  self.primary_key = :coin
  
  validates_presence_of :coin, :address, :decimals
  validates_length_of :coin, :maximum => 8
  validates_length_of :address, :is => 42
  validates_numericality_of :decimals, :only_integer => true, :greater_than_or_equal_to => 0, :less_than_or_equal_to => 18
  
  scope :used, -> { where(:used => true) }
  
  # Return value needed for transfer function (depends on decimals)
  def to_wei(amount)
    Utilities.to_wei(amount, self.decimals)
  end
end
