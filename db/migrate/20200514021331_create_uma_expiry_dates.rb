class CreateUmaExpiryDates < ActiveRecord::Migration[5.2]
  def change
    create_table :uma_expiry_dates do |t|
      t.string :date_str, :null => false, :limit => 16
      t.string :unix, :null => false, :limit => 16
      t.integer :ordinal, :null => false

      t.timestamps
    end
  end
end
