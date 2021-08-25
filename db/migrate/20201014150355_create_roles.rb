class CreateRoles < ActiveRecord::Migration[6.0]
  def up
    create_table :roles do |t|
      t.string :mname, null: false, index: { unique: true }
      t.references :role_category, null: false, foreign_key: {on_delete: :cascade}
      t.float :weight
      t.text :note

      t.timestamps
    end

    add_index :roles, [:mname,  :role_category_id]
    add_index :roles, [:weight, :role_category_id], unique: true

    # Creates root Role (admin)
    if ! RoleCategory.exists?
      warn "WARNING: RoleCategory has no entries, and hence no row is loaded to Table roles."
    else
      root_cat = RoleCategory.root_category
      Role.new do |obj|
        obj.id = 1
        obj.mname = Role::MNAME_SYSADMIN
        obj.role_category = root_cat
        obj.weight = 0
        obj.save!
      end
      puts "NOTE: First Role (id: 1, mname: #{Role::MNAME_SYSADMIN}, role_category_id: #{root_cat.id}, weight: 0) is created."
    end
  end

  # Validation failed: Role category must exist
  def down
    Role.destroy_all
    drop_table :roles
  end
end
