class CopyEtHaToken < ActiveRecord::Migration[5.2]
  def up
    PriceHistory.where(:coin => 'aETH').delete_all
    PriceHistory.where(:coin => 'ETH').each do |ph|
      aph = ph.dup
      aph.coin = 'aETH'
      aph.id = nil
      aph.save!
    end
  end
  
  def down
  end
end
