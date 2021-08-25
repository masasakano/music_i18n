class CreateUserRoleAssocs < ActiveRecord::Migration[6.0]
  # def change  # 'down' is required. For 'down' to be activated, 'up' seems to be needed...
  def up
    create_table :user_role_assocs do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}
      t.references :role, null: false, foreign_key: {on_delete: :cascade}

      t.timestamps
    end

    add_index :user_role_assocs, [:user_id, :role_id], unique: true

    # Initialize root (superuser) account:
    if ! User.find_by(id: 1)
      # warn "WARNING: First User (User-ID=1) is not found."
      return
    end

    if ! Role.find_by(id: 1)
      warn "WARNING: Superuser role (Role-ID=1) is not found, and hence the role is not given to any user."
      return
    end

    UserRoleAssoc.new do |obj|
      obj.user_id = 1
      obj.role_id = 1
      obj.save!
    end
    puts "NOTE: First User (email: #{User.find_by(id: 1).email}) is given a role of Superuser (Role-ID=1)."
  end

  # Without an explicit drop, it would raise
  # PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_user_role_assocs_on_user_id_and_role_id"
  def down
    UserRoleAssoc.destroy_all
    drop_table :user_role_assocs
  end
end
