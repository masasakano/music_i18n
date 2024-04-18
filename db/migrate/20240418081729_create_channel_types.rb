class CreateChannelTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_types, comment: "Channel type like main and sub" do |t|
      t.string :mname, null: false, comment: "machine name (alphanumeric characters only)"
      t.integer :weight, null: false, default: 999, comment: "weight for sorting within this model"
      t.references :create_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.references :update_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.text :note

      t.timestamps
    end
    add_index :channel_types, :mname, unique: true
    add_index :channel_types, :weight
  end
end
