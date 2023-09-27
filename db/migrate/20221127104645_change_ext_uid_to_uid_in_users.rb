class ChangeExtUidToUidInUsers < ActiveRecord::Migration[7.0]
  def change
    # The column name should be "uid" (and "provider")
    # See https://github.com/heartcombo/devise/wiki/OmniAuth:-Overview
    rename_column :users, :ext_uid, :uid
  end
end
