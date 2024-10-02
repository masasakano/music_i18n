class AddIdAtPlatformToChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :channels, :id_at_platform, :string, null: true, comment: "Channel-ID at the remote platform"
    add_index :channels, :id_at_platform
  end
end
