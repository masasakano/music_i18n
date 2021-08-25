class AddUnameToRoles < ActiveRecord::Migration[6.1]
  def change
    add_column :roles, :uname, :string, comment: 'Unique role name'
    add_index  :roles, :uname, unique: true
  end
end
