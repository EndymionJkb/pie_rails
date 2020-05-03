class CreateBalancerPools < ActiveRecord::Migration[5.2]
  def change
    create_table :balancer_pools do |t|
      t.references :pie
      t.column :uma_address, 'character(42)'
      t.column :bp_address, 'character(42)'
      t.date :uma_expiry
      t.text :allocation

      t.timestamps
    end
  end
end
