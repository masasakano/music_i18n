class RemoveUniqueIndexFromNameInRoles < ActiveRecord::Migration[6.1]
  def up
    remove_index :roles, :name  # Remove: unique: true
    add_index    :roles, :name

    remove_index :roles, name: 'index_roles_on_name_and_role_category_id'
    add_index    :roles, [:name, :role_category_id], unique: true, name: 'index_roles_on_name_and_role_category_id'
  end

  def down
    remove_index :roles, name: 'index_roles_on_name_and_role_category_id'  # Remove: unique: true
    add_index    :roles, [:name, :role_category_id], name: 'index_roles_on_name_and_role_category_id'

    remove_index :roles, :name
    add_index    :roles, :name, unique: true
  end
end
