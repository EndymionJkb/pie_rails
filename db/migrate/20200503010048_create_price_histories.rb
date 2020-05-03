class CreatePriceHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :price_histories do |t|
      t.string :coin, :null => false, :limit => 8
      t.date :date, :null => false
      t.numeric :price, :precision => 8, :scale => 2
      t.numeric :pct_change, :precision => 12, :scale => 8

      t.timestamps
    end
    
    add_index :price_histories, [:coin, :date], :unique => true
  end
end
