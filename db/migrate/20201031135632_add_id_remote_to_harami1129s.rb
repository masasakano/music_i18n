class AddIdRemoteToHarami1129s < ActiveRecord::Migration[6.1]
  def change
    add_column :harami1129s, :id_remote, :bigint, comment: 'Row number of the table on the remote URI'
    add_column :harami1129s, :last_downloaded_at, :timestamp, comment: 'Last-checked/downloaded timestamp'

    add_index :harami1129s, :id_remote
    add_index :harami1129s, [:id_remote, :last_downloaded_at], unique: true	
    add_check_constraint :harami1129s, "id_remote IS NULL OR id_remote > 0", name: 'check_positive_id_remote_on_harami1129s'
  end
end
