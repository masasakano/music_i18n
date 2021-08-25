class AddTransUpdatedAtToSexes < ActiveRecord::Migration[6.0]
  def change
    add_column :sexes, :trans_updated_at, :datetime, limit: 6
  end
end
