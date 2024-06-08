class RemoveFlagByHaramiFromHaramiVid < ActiveRecord::Migration[7.0]
  def change
    remove_column :harami_vids, :flag_by_harami, :boolean
  end
end
