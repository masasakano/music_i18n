class CreateChannelPlatforms < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_platforms, comment: "Platform like Youtube" do |t|
      t.string :mname, null: false, comment: "machine name (alphanumeric characters only)"
      t.text :note
      t.bigint :create_user_id
      t.bigint :update_user_id

      t.timestamps
    end

    add_index :channel_platforms, :mname, unique: true	
    reversible do |migr|  # For some reason, the standard rollback fails with "ArgumentError: Table 'channel_platforms' has no foreign key for users"
      migr.up   {
        add_foreign_key :channel_platforms, :users, null: true, column: :create_user_id, on_delete: :nullify
        add_foreign_key :channel_platforms, :users, null: true, column: :update_user_id, on_delete: :nullify
      }
      migr.down   { }
    end
    add_index :channel_platforms, :create_user_id
    add_index :channel_platforms, :update_user_id
  end
end
