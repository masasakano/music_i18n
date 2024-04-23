class CreateChannels < ActiveRecord::Migration[7.0]
  def change
    create_table :channels, comment: "Channel of Youtube etc" do |t|
      t.references :channel_owner,    null: false, foreign_key: true  # on_delete: :restrict
      t.references :channel_type,     null: false, foreign_key: true  # on_delete: :restrict
      t.references :channel_platform, null: false, foreign_key: true  # on_delete: :restrict
      t.references :create_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.references :update_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.text :note

      t.timestamps
    end
    add_index :channels, [:channel_owner_id, :channel_type_id, :channel_platform_id], unique: true, name: "index_unique_all3"
  end
end
