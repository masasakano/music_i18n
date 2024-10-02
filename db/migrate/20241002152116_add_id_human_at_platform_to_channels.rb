class AddIdHumanAtPlatformToChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :channels, :id_human_at_platform, :string, null: true, comment: "Human-readable Channel-ID at remote without <@>"
    add_index :channels, :id_human_at_platform
  end
end
