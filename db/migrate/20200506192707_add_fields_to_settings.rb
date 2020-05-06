class AddFieldsToSettings < ActiveRecord::Migration[5.2]
  def change
    add_column :settings, :focus, :string, :limit => 32
    add_column :settings, :stable_coins, :string
  end
end
