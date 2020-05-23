class AddWithdrawalRequestDeadlineToBalancerPools < ActiveRecord::Migration[5.2]
  def change
    add_column :balancer_pools, :withdrawal_available, :datetime
    add_column :balancer_pools, :pending_withdrawal, :integer
  end
end
