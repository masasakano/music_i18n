class CreateRoleCategories < ActiveRecord::Migration[6.0]
  def up
    create_table :role_categories do |t|
      t.string :mname, null: false
      t.text :note
      t.references :superior

      t.timestamps
    end

    add_index :role_categories, :mname, unique: true

    # Creates root Role (admin)
    RoleCategory.new do |obj|
      obj.id = 1
      obj.mname = RoleCategory::MNAME_ROOT
      obj.save!
    end
    puts "NOTE: First RoleCategory (id: 1, mname: #{RoleCategory::MNAME_ROOT}) is created."
  end

  # ActiveRecord::RecordInvalid: Validation failed: Mname has already been taken
  def down
    RoleCategory.destroy_all rescue nil
    drop_table :role_categories rescue nil
    begin
      drop_table :role_categories
    rescue
      begin
        execute <<-SQL
        DROP TABLE "role_categories" ;
        SQL
      rescue
      end
    end

    # DELETE FROM schema_migrations WHERE version = '20201014145143';
    # For some reason, this will ROLLBACK after this last line.
  end
end
