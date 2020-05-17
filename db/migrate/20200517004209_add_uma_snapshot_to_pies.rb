class AddUmaSnapshotToPies < ActiveRecord::Migration[5.2]
  def change
    add_column :pies, :uma_snapshot, :text
  end
end
