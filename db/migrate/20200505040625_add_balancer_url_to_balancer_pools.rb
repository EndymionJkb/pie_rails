class AddBalancerUrlToBalancerPools < ActiveRecord::Migration[5.2]
  def change
    add_column :balancer_pools, :balancer_url, :string
  end
end
