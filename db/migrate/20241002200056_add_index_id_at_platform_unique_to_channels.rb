class AddIndexIdAtPlatformUniqueToChannels < ActiveRecord::Migration[7.0]
  def change
    add_index :channels, %w(channel_platform_id id_at_platform), unique: true, name: 'index_unique_channel_platform_its_id'
      # rows with null are ignored (do not violate unique constraint) in PostgreSQL etc (but NOT in Microsoft SQL)
  end
end
