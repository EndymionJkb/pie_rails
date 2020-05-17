class AddSwapsCompletedToBalancerPools < ActiveRecord::Migration[5.2]
  def change
    add_column :balancer_pools, :swaps_completed, :boolean, :null => false, :default => false
  end
end
