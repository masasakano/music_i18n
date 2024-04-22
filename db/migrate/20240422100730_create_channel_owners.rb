class CreateChannelOwners < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_owners, comment: "Owner of a Channel" do |t|
      t.boolean :themselves, default: false, index: true, comment: "true if identical to an Artist"
      t.references :create_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.references :update_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.text :note

      t.timestamps
    end
  end
end
