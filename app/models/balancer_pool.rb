# == Schema Information
#
# Table name: balancer_pools
#
#  id          :bigint           not null, primary key
#  pie_id      :bigint
#  uma_address :string(42)
#  bp_address  :string(42)
#  uma_expiry  :date
#  allocation  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class BalancerPool < ApplicationRecord
  belongs_to :pie
  
  validates_length_of :uma_address, :bp_address, :is => 42, :allow_nil => true
end
