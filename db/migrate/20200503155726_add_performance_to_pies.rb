class AddPerformanceToPies < ActiveRecord::Migration[5.2]
  def change
    add_column :pies, :performance, :text
  end
end
