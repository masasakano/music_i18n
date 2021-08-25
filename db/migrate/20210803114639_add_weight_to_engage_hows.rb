class AddWeightToEngageHows < ActiveRecord::Migration[6.1]
  def change
    add_column :engage_hows, :weight, :float, default: 999
  end
end
