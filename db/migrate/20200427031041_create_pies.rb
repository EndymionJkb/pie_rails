class CreatePies < ActiveRecord::Migration[5.2]
  def change
    create_table :pies do |t|
      t.references :user
      t.integer :pct_gold
      t.integer :pct_crypto
      t.integer :pct_cash
      t.integer :pct_equities
      t.string :name, :limit => 32

      t.timestamps
    end
  end
end
