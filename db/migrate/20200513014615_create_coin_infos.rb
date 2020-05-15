class CreateCoinInfos < ActiveRecord::Migration[5.2]
  def change
    create_table :coin_infos, :id => false do |t|
      t.string :coin, :null => false, :limit => 8
      t.string :address, :null => false, :limit => 42
      t.integer :decimals, :null => false, :default => 18
      t.boolean :used, :null => false, :default => false
      t.text :abi
      
      t.timestamps
    end
    
    add_index :coin_infos, :coin, :unique => true
  end
end
