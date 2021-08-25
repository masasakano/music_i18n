class AddDisplayNameToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :display_name, :string, null: false, default: ""
    add_column :users, :ext_account_name, :string
    add_column :users, :ext_uid, :string
    add_column :users, :provider, :string
  end
end
