class CreateEtfs < ActiveRecord::Migration[5.2]
  def change
    create_table :etfs do |t|
      t.string :ticker, :limit => 32, :null => false
      t.string :fund_name, :limit => 128, :null => false
      t.numeric :forecast_e, :precision => 8, :scale => 4
      t.numeric :forecast_s, :precision => 8, :scale => 4
      t.numeric :forecast_g, :precision => 8, :scale => 4
      t.numeric :esg_performance, :precision => 8, :scale => 4
      t.numeric :alpha, :precision => 10, :scale => 6
      t.numeric :benchmark, :precision => 10, :scale => 6

      t.timestamps
    end
  end
end
