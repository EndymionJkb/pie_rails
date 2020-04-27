class CreateSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :settings do |t|
      t.references :user
      t.integer :e_priority, :null => false
      t.integer :s_priority, :null => false
      t.integer :g_priority, :null => false

      t.timestamps
    end
  end
end
