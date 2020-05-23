class AddFinalizedToBalancerPools < ActiveRecord::Migration[5.2]
  def change
    add_column :balancer_pools, :finalized, :boolean, :null => false, :default => false
    add_column :balancer_pools, :pending_changes, :text
  end
end
