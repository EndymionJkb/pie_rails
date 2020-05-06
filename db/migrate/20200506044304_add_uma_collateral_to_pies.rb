class AddUmaCollateralToPies < ActiveRecord::Migration[5.2]
  def up
    add_column :pies, :uma_collateral, :string, :limit => 8
    add_column :pies, :uma_token_name, :string, :limit => 32
    add_column :pies, :uma_expiry_date, :string, :limit => 16
    remove_column :balancer_pools, :uma_expiry
  end
  
  def down
    remove_column :pies, :uma_collateral
    remove_column :pies, :uma_token_name
    remove_column :pies, :uma_expiry_date
    add_column :balancer_pools, :uma_expiry, :date  
  end
end
