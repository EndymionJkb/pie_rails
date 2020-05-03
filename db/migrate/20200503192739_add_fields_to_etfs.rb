class AddFieldsToEtfs < ActiveRecord::Migration[5.2]
  def up
    remove_column :etfs, :benchmark
    add_column :etfs, :m1_return, :numeric, :precision => 10, :scale => 6
    add_column :etfs, :m3_return, :numeric, :precision => 10, :scale => 6
    add_column :etfs, :m6_return, :numeric, :precision => 10, :scale => 6
    add_column :etfs, :y1_return, :numeric, :precision => 10, :scale => 6
  end
  
  def down
    add_column :etfs, :benchmark, :numeric, :precision => 10, :scale => 6
    remove_column :etfs, :m1_return
    remove_column :etfs, :m3_return
    remove_column :etfs, :m6_return
    remove_column :etfs, :y1_return
    
  end
end
