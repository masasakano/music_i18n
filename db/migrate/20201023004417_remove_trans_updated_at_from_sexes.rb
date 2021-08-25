class RemoveTransUpdatedAtFromSexes < ActiveRecord::Migration[6.0]
  def change
    remove_column :sexes, :trans_updated_at, :datetime
  end
end
