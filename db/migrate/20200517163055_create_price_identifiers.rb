class CreatePriceIdentifiers < ActiveRecord::Migration[5.2]
  def change
    create_table :price_identifiers do |t|
      t.references :pie
      t.string :whitelisted, :null => false

      t.timestamps
    end
  end
end
