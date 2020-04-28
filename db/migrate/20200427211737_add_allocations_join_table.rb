class AddAllocationsJoinTable < ActiveRecord::Migration[5.2]
  def change
    create_table :etfs_pies, :id => false do |t|
      t.references :pie
      t.references :etf
    end

    create_table :pies_stocks, :id => false do |t|
      t.references :pie
      t.references :stock
    end
  end
end
